const puppeteer = require("puppeteer");
const fs = require("fs");
const path = require("path");
const cheerio = require("cheerio");

// 读取配置文件
const config = JSON.parse(
  fs.readFileSync(path.join(__dirname, "config.json"), "utf-8")
);

async function setCookies(page, cookies) {
  await page.setCookie(...cookies);
}

async function setLocalStorage(page, localStorageData) {
  await page.evaluate((localStorageData) => {
    for (const key in localStorageData) {
      localStorage.setItem(key, localStorageData[key]);
    }
  }, localStorageData);
}

async function waitForNetworkIdle(page, timeout = 250) {
  await page.waitForNetworkIdle({ idleTime: timeout });
}

async function monitorDOMChanges(page, targetSelector) {
  await page.evaluate(
    ({ selector }) => {
      const targetNode = document.querySelector(selector);
      const fragment = (window._div = document.createElement("div"));

      for (let node of [...targetNode.childNodes]) {
        fragment.appendChild(node.cloneNode(true));
      }

      const observer = new MutationObserver((mutationList) => {
        for (const mutation of mutationList) {
          if (mutation.type === "childList" && mutation.addedNodes.length) {
            for (let node of [...mutation.addedNodes]) {
              fragment.appendChild(node.cloneNode(true));
            }
          }
        }
      });
      observer.observe(targetNode, { childList: true });
    },
    { selector: targetSelector }
  );
}
async function handleImages($, page, imageDir) {
  const promises = [];
  $("img").each((index, element) => {
    const src = $(element).attr("src");
    promises.push(
      page
        .evaluate(async (src) => {
          const response = await fetch(src);
          const data = await response.blob();
          const type = data.type.split("/")[1] || 'png';
          const reader = new FileReader();
          reader.readAsBinaryString(data);
          let resolve;
          const promise = new Promise(r => {
            resolve = r
          })
          reader.onloadend = () => {
            debugger;
resolve({
            data: reader.result,
            type
          })
          };
          reader.onerror = () => reject('Error occurred while reading binary string');
          return promise
        }, src)
        .then(({ data, type }) => {
          const localPath = path.join(imageDir, `image${index}.${type}`);
          fs.writeFileSync(localPath, Buffer.from(data, "binary"));
          $(element).attr("src", localPath);
        })
    );
  });
  await Promise.all(promises);
}

async function scrollToBottom(page, scrollDistance) {
  const previousHeight = await page.evaluate(
    "document.documentElement.scrollTop"
  );
  await page.evaluate((scrollDistance) => {
    window.scrollBy(0, scrollDistance);
  }, scrollDistance);
//   await waitForNetworkIdle(page); // 等待 2 秒，确保新的内容加载完成
  const currentHeight = await page.evaluate(
    "document.documentElement.scrollTop"
  );
  return previousHeight === currentHeight; // 如果高度没有变化，说明已经到底部
}

(async () => {
  const browser = await puppeteer.launch({ headless: false });
  const page = await browser.newPage();

  // 设置 cookie 和 localStorage
  await setCookies(page, config.cookies);
  await page.goto("https://yitang.top");
  await setLocalStorage(page, config.localStorage);

  // 打开目标网页
  await page.goto(config.url);
  await page.waitForSelector(config.targetSelector);

  await monitorDOMChanges(page, config.targetSelector);

  while (true) {
    // 逐步滚动页面
    const isBottom = await scrollToBottom(page, config.scrollDistance);

    if (isBottom) {
      break;
    }
  }

  const finalHTML = await page.evaluate("window._div.innerHTML");

  // 拼接 DOM 并处理图片
  const $ = cheerio.load(finalHTML);
  const imageDir = './images'
  if (!fs.existsSync(imageDir)) {
    fs.mkdirSync(imageDir);
  }

  await handleImages($, page, imageDir);

  // 保存最终的 HTML 内容
  const finalHTMLWithStyles = `<html><head>${$("head").html()}</head><body>${$(
    "body"
  ).html()}</body></html>`;
  fs.writeFileSync("final.html", finalHTMLWithStyles);

  await browser.close();
})();
