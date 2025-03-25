// ==UserScript==
// @name         去掉飞书虚拟滚动
// @namespace    http://tampermonkey.net/
// @version      0.2
// @description  去掉飞书虚拟滚动，连接整个网页并转换 Blob 图片为 Base64
// @author       You
// @match        https://*.feishu.cn/doc*
// @icon         https://www.google.com/s2/favicons?sz=64&domain=feishu.cn
// @grant        none
// @license      MIT
// ==/UserScript==

(function () {
  "use strict";
  const type = window.location.pathname.split("/")[1];
  const configMap = {
    docx: {
      scrollContainerSelector: ".bear-web-x-container",
      contentContainerSelector: ".render-unit-wrapper",
      nodeAttribute: "data-record-id",
    },
    doc: {
      scrollContainerSelector: ".etherpad-container-wrapper",
      contentContainerSelector: ".innerdocbody",
      nodeAttribute: "data-node",
    },
    "fs-doc": {
      scrollContainerSelector: "html",
      contentContainerSelector:
        '.page-block-children > .virtual-list > [role="group"]',
      nodeAttribute: "role",
      navSelector: '.directory-menu [role="tree"]',
      initialScrollTopNavText: "开始讲课",
      getNodeId: (node) =>
        [...node.classList].find((cls) => cls.match(/item-([A-Za-z].*)/)),
    },
    common: {
      initialScrollTopNavText: "开始上课",
      scrollGap: 300,
      scrollInterval: 600,
      navSelector: ".catalogue li a",
      placeholderSelectors: ["[class*=placeholder]", ".isEmpty"],
    },
  };
  if (!configMap[type]) return;

  const _feishu = {
    stop: () => {},
    fragment: null,
  };
  Object.assign(window, { _feishu });

  const {
    scrollContainerSelector,
    contentContainerSelector,
    nodeAttribute,
    navSelector,
    placeholderSelectors,
    initialScrollTopNavText,
    scrollGap,
    scrollInterval,
    getNodeId,
  } = Object.assign({}, configMap.common, configMap[type]);

  const imageHandlerConfig = {
    retryCount: 2, // 失败重试次数
    timeout: 5000, // 单图超时时间
    skipTypes: new Set(["image/svg+xml"]), // 跳过处理的类型
  };
  // 新增：Blob 转 Base64 函数
  // 优化后的图片转换器
  // 智能图片转换器
  async function convertToBase64(url) {
    // 跳过已处理的图片
    if (url.startsWith("data:")) return url;

    try {
      let response;
      // 区分 Blob 和普通请求
      if (url.startsWith("blob:")) {
        response = await fetch(url);
        const blob = await response.blob();
        return await new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = () => resolve(reader.result);
          reader.onerror = reject;
          reader.readAsDataURL(blob);
        });
      } else {
        // 普通图片使用 arrayBuffer 避免 401
        response = await fetch(url, {
          credentials: "include", // 携带 cookie
          mode: "cors", // 强制 CORS 模式
        });
        const buffer = await response.arrayBuffer();
        const type = response.headers.get("Content-Type") || "image/png";
        const base64 = btoa(
          new Uint8Array(buffer).reduce(
            (data, byte) => data + String.fromCharCode(byte),
            "",
          ),
        );
        return `data:${type};base64,${base64}`;
      }
    } catch (error) {
      console.warn("[图片转换失败]", url, error);
      return url; // 失败时保留原 URL
    }
  }

  // 优化后的片段处理器
  async function processFragment(fragment) {
    const images = fragment.querySelectorAll("img[src]");
    const promises = Array.from(images).map(async (img) => {
      try {
        const originalSrc = img.src;
        const newSrc = await convertToBase64(originalSrc);
        // 防止多次重复处理
        if (img.src === originalSrc) {
          img.src = newSrc;
        }
      } catch (error) {
        console.error("图片处理异常:", error);
      }
    });

    await Promise.allSettled(promises);
    return fragment;
  }

  async function accumulate() {
    const scrollContainer = document.querySelector(scrollContainerSelector);
    const contentContainer = document.querySelector(contentContainerSelector);
    await setScrollTop();
    const frag = await scroll(scrollContainer, contentContainer, {
      scrollGap,
      scrollInterval,
    });
    return frag;
  }

  function appendFragment(frag) {
    document.body.innerHTML = "";
    document.body.style.cssText = `
        width: 80%;
        padding: 0 100px;
        margin: auto;
        height: auto;
        overflow: auto;
    `;
    setTimeout(() => {
      document.body.appendChild(frag);
    }, 1000);
  }

  function scroll(el, container, options) {
    let resolve;
    el.scrollTo(0, 2000);
    function clearFragment(fragment) {
      placeholderSelectors.forEach((placeholderSelector) => {
        [...fragment.querySelectorAll(placeholderSelector).values()].forEach(
          (placeholder) => {
            placeholder.remove();
          },
        );
      });
    }
    const promise = new Promise((r) => (resolve = r));
    const fragment = observe(container);
    const { scrollGap, scrollInterval } = Object.assign(
      {
        scrollGap: 300,
        scrollInterval: 800,
      },
      options,
    );

    let lastScrollHeight = -1;

    const end = (_feishu.stop = () => {
      clearInterval(interval);
      resolve(fragment);
    });
    const interval = setInterval(() => {
      if (el.scrollTop === lastScrollHeight) {
        end();
        return;
      }
      lastScrollHeight = el.scrollTop;
      el.scrollBy(0, scrollGap);
    }, scrollInterval);

    return promise;
  }

  function observe(target, callback) {
    const fragment = (_feishu.fragment = document.createDocumentFragment());

    appendNodes(target.childNodes);

    function appendNodes(nodes) {
      for (let node of [...nodes]) {
        if (
          node.hasAttribute(nodeAttribute) &&
          (node.innerText !== "" ||
            node.querySelector("[href]") ||
            node.querySelector("[src]"))
        ) {
          const alterNode = node.cloneNode(true);
          if (getNodeId) {
            const addedNode = [...fragment.childNodes].find(
              (child) => getNodeId(child) === getNodeId(node),
            );
            if (addedNode) {
              addedNode.parentNode.replaceChild(fragment, alterNode);
              continue;
            }
          }
          fragment.appendChild(alterNode);
        }
      }
    }

    const observer = new MutationObserver((mutationsList) => {
      for (let mutation of mutationsList) {
        if (mutation.type === "childList") {
          setTimeout(() => {
            appendNodes(mutation.addedNodes);
          }, 3000);
        }
      }

      if (callback) {
        callback(fragment);
      }
    });

    observer.observe(target, {
      childList: true,
    });

    return fragment;
  }

  async function setScrollTop() {
    const els = document.querySelectorAll(navSelector);
    let anchor;
    for (let i = 0; i < els.length; i++) {
      let el = els[i];
      if (el.innerText.includes(initialScrollTopNavText)) {
        anchor = el;
      }
    }
    if (!anchor) {
      anchor = els[0];
    }
    anchor.click();
    await wait(2000);
  }

  async function wait(ms) {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  async function waitPageLoad() {
    return new Promise((resolve) => {
      if (document.readyState === "complete") resolve();
      window.addEventListener("load", async (event) => {
        await wait(1000);
        resolve();
      });
    });
  }

  async function main() {
    await waitPageLoad();
    const frag = await accumulate();
    const processedFrag = await processFragment(frag); // 新增处理步骤
    document.body.innerHTML = "";
    setTimeout(() => {
      appendFragment(processedFrag);
    }, 5000);
  }

  main();
})();

