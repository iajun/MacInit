import {
  chromium,
  ElementHandle,
  type Browser,
  type BrowserContext,
  type Page,
} from "playwright";
import fs from "fs";
import { load } from "cheerio";
import config from "../config.json";
import { omit } from "lodash-es";
import { getDir } from "./utils";
import path from "path";
import { parseYitangLessonSectionUrl } from "./lessonSectionUrl";

type DocType = "docx" | "doc" | "docs" | "fs-doc";

interface ScrollerConfig {
  scrollContainer?: string;
  contentContainer: string;
  nodeAttribute?: string;
  navSelector: string;
  placeholderSelectors: string[];
  initialScrollText: string;
  scrollGap: number;
  scrollInterval: number;
  getNodeId?: (node: ElementHandle) => Promise<string | null>;
}


type ExtractPromise<T> = T extends Promise<infer U> ? U : never;

type BrowserContextCookie = ExtractPromise<
  ReturnType<BrowserContext["storageState"]>
>["cookies"][number];

interface ProcessOptions {
  url: string;
  cookies?: BrowserContextCookie[];
  localStorage?: Record<string, string>;
  timeout?: number;
}

const MAX_CONTENT_NODES = Infinity;

/** Shared across multiple processImages calls (e.g. multi-page lesson sections). */
type ProcessImagesDedupe = {
  seenBase64: Set<string>;
  lockHolder: { current: Promise<void> };
};

export class FeishuDocScraper {
  private browser!: Browser;
  private logger = console;

  async initialize() {
    let opts = config.debug ? { headless: false, devtools: true } : {};
    this.browser = await chromium.launch(opts);
    this.logger.info("Scraper initialized");
  }

  // https://yitanger.feishu.cn/docx/ShLWdyixCoO6fdxB3fKcU9plnmf
  // https://yitang.top/fs-doc/ac9466faf398607a37e821e4b654e4bf/CIcTdnB7voQdNpxFPZzc7NIpnie?_uds=hyyy_biu
  private buildScrollerConfig(url: string): ScrollerConfig {
    const urlObj = new URL(url);
    const docType = urlObj.pathname.split("/")[1];
    if (!docType || !["docx", "doc", "docs", "fs-doc"].includes(docType)) {
      throw new Error("Invalid URL");
    }

    const baseConfig = {
      navSelector: ".catalogue li a",
      placeholderSelectors: ["[class*=placeholder]", ".isEmpty"],
      initialScrollText: "开始讲课",
      scrollGap: 800,
      scrollInterval: 800
    };

    const typeConfigs: Record<DocType, Partial<ScrollerConfig>> = {
      docx: {
        scrollContainer: ".bear-web-x-container",
        contentContainer: ".render-unit-wrapper",
        nodeAttribute: "data-record-id",
      },
      doc: {
        scrollContainer: ".etherpad-container-wrapper",
        contentContainer: ".innerdocbody",
        nodeAttribute: "data-node",
      },
      docs: {
        scrollContainer: ".etherpad-container-wrapper",
        contentContainer: ".adit-container.maindocbody",
        nodeAttribute: "id",
      },
      "fs-doc": {
        contentContainer:
          '.page-block-children > .virtual-list > [role="group"]',
        nodeAttribute: "role",
        getNodeId: async (node: ElementHandle) => {
          const classList = await node.getAttribute("class");
          return classList?.match(/item-([a-zA-Z0-9]+) listitem/)?.[1] ?? null;
        },
      },
    };

    return {
      ...baseConfig,
      ...typeConfigs[docType as DocType],
    } as ScrollerConfig;
  }

  async process(options: ProcessOptions) {
    const { url, cookies, localStorage, timeout = 30000 } = options;
    const scrollerConfig = this.buildScrollerConfig(url);
    const contentNodes = new Map<string, string>();
    const context = await this.createAuthContext(url, cookies, localStorage);
    context.addInitScript({
      content: fs.readFileSync(path.join(getDir(import.meta.url), "inject.js"), "utf-8"),
    });
    const page = await context.newPage();

    try {
      await page.goto(url, { waitUntil: "networkidle", timeout });
      await this.handleInitialNavigation(page, scrollerConfig);
      const styleHTML = (
        await Promise.all(
          Array.from(await page.$$("style")).map(
            async (node) => await node.evaluate((node) => node.outerHTML)
          )
        )
      ).join("\n");
      const title = await page.evaluate(() => document.title);
      await this.collectContent(page, contentNodes, scrollerConfig);
      await this.processImages(page, contentNodes);
      return {
        contentNodes,
        title,
        styleHTML,
      }
    } finally {
      await context.close();
    }
  }

  /**
   * yitang.top /lesson/section/83,24,55：按顺序抓取各节 `.section-markdown-content`，
   * 样式仅取第一节所在页；每节在当前页做图片内联，去重状态跨节共享。
   */
  async processLessonSections(options: ProcessOptions) {
    const { url, cookies, localStorage, timeout = 30000 } = options;
    const parsed = parseYitangLessonSectionUrl(url);
    if (!parsed) {
      throw new Error("Not a yitang.top lesson section URL (expected /lesson/section/{id} or id,id,...)");
    }

    const { origin, sectionIds } = parsed;
    const contentNodes = new Map<string, string>();
    const context = await this.createAuthContext(url, cookies, localStorage);
    context.addInitScript({
      content: fs.readFileSync(path.join(getDir(import.meta.url), "inject.js"), "utf-8"),
    });
    const page = await context.newPage();

    const dedupe: ProcessImagesDedupe = {
      seenBase64: new Set<string>(),
      lockHolder: { current: Promise.resolve() },
    };

    let styleHTML = "";
    let title = "";

    try {
      for (let i = 0; i < sectionIds.length; i++) {
        const id = sectionIds[i];
        const sectionUrl = `${origin}/lesson/section/${id}`;
        this.logger.info(`Lesson section ${i + 1}/${sectionIds.length}: ${sectionUrl}`);

        await page.goto(sectionUrl, { waitUntil: "networkidle", timeout });
        await page.waitForSelector(".section-markdown-content", { timeout });

        if (i === 0) {
          styleHTML = (
            await Promise.all(
              Array.from(await page.$$("style")).map(
                async (node) => await node.evaluate((n) => n.outerHTML)
              )
            )
          ).join("\n");
          title = await page.title();
        }

        const innerHtml = await page.$eval(".section-markdown-content", (el) => el.innerHTML);
        const nodeKey = `lesson-${id}`;
        const wrapped = `<div role="listitem" class="item-${id} lesson-section-markdown">${innerHtml}</div>`;

        const chunk = new Map<string, string>([[nodeKey, wrapped]]);
        await this.processImages(page, chunk, dedupe);
        contentNodes.set(nodeKey, chunk.get(nodeKey)!);
      }

      return {
        contentNodes,
        title,
        styleHTML,
      };
    } finally {
      await context.close();
    }
  }

  private async createAuthContext(
    url: string,
    cookies?: BrowserContextCookie[],
    localStorage?: Record<string, string>
  ): Promise<BrowserContext> {
    const context = await this.browser.newContext({
      storageState: {
        cookies: (cookies ?? []).map((item) => omit(item, ["sameSite"])) as any,
        origins: [
          {
            origin: new URL(url).origin,
            localStorage: Object.entries(localStorage ?? {}).map(
              ([key, value]) => ({ name: key, value })
            ),
          },
        ],
      },
    });

    if (cookies?.length) {
      this.logger.debug(`Added ${cookies.length} cookies`);
    }

    if (localStorage) {
      this.logger.debug(
        `Added ${Object.keys(localStorage).length} localStorage items`
      );
    }

    return context;
  }

  private async handleInitialNavigation(page: Page, scrollerConfig: ScrollerConfig) {
    try {
      const navItem = await page.waitForSelector(
        `${scrollerConfig.navSelector} >> text=${scrollerConfig.initialScrollText}`,
        { timeout: 5000 }
      );

      await navItem.click();
      await page.waitForTimeout(2000);
      this.logger.info("Initial navigation completed");
    } catch (error) {
      this.logger.warn(
        "Initial navigation target not found, using default position"
      );
    }
  }

  private async collectContent(
    page: Page,
    contentNodes: Map<string, string>,
    scrollerConfig: ScrollerConfig
  ) {
    let lastSize = 0;
    let sameCount = 0;
    const maxRetries = 10;

    while (sameCount < maxRetries && contentNodes.size < MAX_CONTENT_NODES) {
      await this.scrollPage(page, scrollerConfig);
      try {
        await this.captureNodes(page, contentNodes, scrollerConfig);
      } catch (error) {
        this.logger.error(error);
      }

      if (contentNodes.size === lastSize) {
        sameCount++;
        this.logger.debug(
          `No new content detected (${sameCount}/${maxRetries})`
        );
      } else {
        lastSize = contentNodes.size;
        sameCount = 0;
      }
    }

    this.logger.info(`Collected ${contentNodes.size} content nodes`);
  }

  private async scrollPage(page: Page, scrollerConfig: ScrollerConfig) {
    await page.evaluate(
      ({ scrollGap, scrollContainer }) => {
        let container: any = window;
        if (scrollContainer) {
          container = document.querySelector(scrollContainer);
        }
        container?.scrollBy({ top: scrollGap, behavior: "smooth" });
      },
      { scrollGap: scrollerConfig.scrollGap, scrollContainer: scrollerConfig.scrollContainer }
    );

    await page.waitForTimeout(scrollerConfig.scrollInterval);
  }

  private async captureNodes(
    page: Page,
    contentNodes: Map<string, string>,
    scrollerConfig: ScrollerConfig
  ) {
    const nodes = await page.$$(`${scrollerConfig.contentContainer} > *`);

    for (const nodeHandle of nodes) {
      let nodeId: string | null = null;
      if (scrollerConfig.getNodeId) {
        nodeId = await scrollerConfig.getNodeId(nodeHandle);
      } else if (scrollerConfig.nodeAttribute) {
        nodeId = await nodeHandle.getAttribute(scrollerConfig.nodeAttribute);
      }

      if (nodeId && !nodeId.startsWith("placeholder-id-")) {
        const html = await nodeHandle.evaluate((node) => {
          node.querySelectorAll("[aria-hidden]").forEach((el) => el.remove());
          return node.outerHTML;
        });

        if (
          !contentNodes.has(nodeId) ||
          contentNodes.get(nodeId) !== html
        ) {
          contentNodes.set(nodeId, html);
          this.logger.debug(`Captured node: ${nodeId}`);
        }
      }
    }
  }

  private async processImages(
    page: Page,
    contentNodes: Map<string, string>,
    sharedDedupe?: ProcessImagesDedupe
  ) {
    const nodeEntries = Array.from(contentNodes.entries());
    const seenBase64 = sharedDedupe?.seenBase64 ?? new Set<string>();
    const lockHolder = sharedDedupe?.lockHolder ?? { current: Promise.resolve() };

    const withDedupeLock = async <T>(fn: () => T | Promise<T>): Promise<T> => {
      const run = lockHolder.current.then(fn, fn);
      lockHolder.current = run.then(
        () => undefined,
        () => undefined
      );
      return run;
    };

    // 并行处理所有节点的图片
    await Promise.all(
      nodeEntries.map(async ([nodeId, html]) => {
        const $ = load(html);
        const imgElements = $("img").toArray();

        // 串行处理单节点内的图片
        for (const img of imgElements) {
          const $img = $(img);
          const src = $img.attr("src");

          if (!src) continue;

          try {
            // 在浏览器上下文执行转换
            const base64 = await page.evaluate(async (src) => {
              return (window as any).convertToBase64(src);
            }, src);

            const isDuplicate = await withDedupeLock(() => {
              if (seenBase64.has(base64)) return true;
              seenBase64.add(base64);
              return false;
            });

            if (isDuplicate) {
              $img.remove();
              continue;
            }

            $img.attr("src", base64);
          } catch (error) {
            this.logger.error(`[${nodeId}] 图片处理失败: ${src}`, error);
            const message = error instanceof Error ? error.message : String(error);
            $img.attr("data-error", message);
          }
        }

        contentNodes.set(nodeId, $.html());
      })
    );
  }

  async close() {
    await this.browser.close();
  }
}

