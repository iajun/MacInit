// ==UserScript==
// @name         去掉飞书虚拟滚动
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  去掉飞书虚拟滚动，连接整个网页
// @author       You
// @match        https://*.feishu.cn/doc*
// @icon         https://www.google.com/s2/favicons?sz=64&domain=feishu.cn
// @grant        none
// @license      MIT
// ==/UserScript==

(function () {
  "use strict";
  const isDocx = window.location.href.includes('docx');
  const isDoc = window.location.href.includes('docs');
  const configMap = {
      docx: {
          scrollContainerSelector: '.bear-web-x-container',
          contentContainerSelector: '.render-unit-wrapper',
          nodeAttribute: 'data-record-id'
      },
      doc: {
          scrollContainerSelector: '.etherpad-container-wrapper',
          contentContainerSelector: '.innerdocbody',
          nodeAttribute: 'data-node'
      },
      common: {
          initialScrollTopNavText: '开始上课',
          scrollGap: 300,
        scrollInterval: 600,
          navSelector: '.catalogue li a',
          placeholderSelectors: ['[class*=placeholder]', '.isEmpty'],
      }
  }
  if (!isDocx && !isDoc) return;

    const _feishu = {
      stop: () => {},
      fragment: null
  }
  Object.assign(window, {_feishu});


  const {
      scrollContainerSelector,
          contentContainerSelector,
          nodeAttribute,
      navSelector,
      placeholderSelectors,
initialScrollTopNavText,
      scrollGap,
      scrollInterval

  } = Object.assign({}, configMap[isDocx ? 'docx' : 'doc'], configMap.common);
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
    setTimeout(() =>  {
        document.body.appendChild(frag);
    }, 1000)
  }

  function scroll(el, container, options) {
    let resolve;
      function clearFragment(fragment) {
          placeholderSelectors.forEach(placeholderSelector => {

          [...fragment.querySelectorAll(placeholderSelector).values()].forEach(placeholder => {
              placeholder.remove();
          })
              })
      }
    const promise = new Promise((r) => (resolve = r));
    const fragment = observe(container);
    const { scrollGap, scrollInterval } = Object.assign(
      {
        scrollGap: 300,
        scrollInterval: 800,
      },
      options
    );

    let lastScrollHeight = -1;

    const end = (_feishu.stop = () => {
      clearInterval(interval);
//        clearFragment(fragment);
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
          (node.innerText !== '' || node.querySelector('[href]'))
        ) {
          const alterNode = node.cloneNode(true);
          console.log(alterNode, alterNode.innerText)
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
    document.body.innerHTML = '';
    setTimeout(() => {
        appendFragment(frag);
    }, 5000)
  }

  main();
})();

