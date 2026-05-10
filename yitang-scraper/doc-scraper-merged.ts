import fs from "fs";
import path from "path";
import { Readable } from "stream";

import { load } from "cheerio";
import { omit } from "lodash-es";
import { Parser } from "htmlparser2";
import {
  chromium,
  type Browser,
  type BrowserContext,
  type ElementHandle,
  type Page,
} from "playwright";

type DocType = "docx" | "doc" | "fs-doc";

interface ScrollerConfig {
  scrollContainer: string;
  contentContainer: string;
  nodeAttribute: string;
  navSelector: string;
  placeholderSelectors: string[];
  initialScrollText: string;
  scrollGap: number;
  scrollInterval: number;
  getNodeId: (node: ElementHandle) => Promise<string | null>;
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
  debug?: boolean;
}

interface HeadingNode {
  id: string;
  text: string;
  level: number;
  children: HeadingNode[];
}

const here = (() => {
  // In ESM, `__dirname` is undefined; in CJS it exists.
  // eslint-disable-next-line no-undef
  if (typeof __dirname !== "undefined") return __dirname;
  return path.dirname(new URL(import.meta.url).pathname);
})();

const MAX_CONTENT_NODES = Infinity;

// Inline inject.js to keep the scraper fully self-contained.
const injectJs = `async function convertToBase64(url) {
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
                // credentials: "include", // 携带 cookie
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
            return \`data:\${type};base64,\${base64}\`;
        }
    } catch (error) {
        console.warn("[图片转换失败]", url, error);
        return url; // 失败时保留原 URL
    }
}

window.convertToBase64 = convertToBase64;
`;

function loadJson(filePath: string) {
  return JSON.parse(fs.readFileSync(filePath, "utf-8"));
}

function initDownloadDir(downloadDir: string) {
  if (!fs.existsSync(downloadDir)) fs.mkdirSync(downloadDir, { recursive: true });
}

function insertHeadingIntoTree(heading: HeadingNode, headingTree: HeadingNode[]) {
  if (headingTree.length === 0) {
    headingTree.push(heading);
    return;
  }

  // 找到合适的父级标题
  let currentPath: HeadingNode[] = [headingTree[0]];
  for (let i = 1; i < headingTree.length; i++) {
    const node = headingTree[i];

    if (node.level < heading.level) {
      currentPath = headingTree.slice(0, i + 1);
    } else if (node.level === heading.level) {
      currentPath = headingTree.slice(0, i);
      break;
    } else {
      break;
    }
  }

  let parent = currentPath[currentPath.length - 1];
  while (
    parent.children.length > 0 &&
    parent.children[parent.children.length - 1].level < heading.level
  ) {
    parent = parent.children[parent.children.length - 1];
  }

  if (parent.level < heading.level) {
    parent.children.push(heading);
  } else {
    headingTree.push(heading);
  }
}

function generateNavigation(headingTree: HeadingNode[]): string {
  if (headingTree.length === 0) return "";

  const generateNavItems = (headings: HeadingNode[]): string => {
    return headings
      .map((heading) => {
        const children =
          heading.children.length > 0 ? generateNavItems(heading.children) : "";

        return `
          <li class="nav-item nav-level-${heading.level}">
            <a href="#${heading.id}" class="nav-link">${heading.text}</a>
            ${children ? `<ul class="nav-children">${children}</ul>` : ""}
          </li>
        `;
      })
      .join("");
  };

  return `
      <button class="nav-toggle" aria-label="切换导航">
        <span class="nav-arrow">▶</span>
      </button>
      <nav class="page-navigation">
        <div class="nav-header">
          <span class="nav-title">导航</span>
        </div>
        <ul class="nav-list">
          ${generateNavItems(headingTree)}
        </ul>
      </nav>
    `;
}

function extractHeadings(contentNodes: Map<string, string>) {
  const headingTree: HeadingNode[] = [];

  for (const [nodeId, html] of contentNodes) {
    const $ = load(html);

    // 查找所有标题元素
    const headings = $('[class*="docx-heading"], [class*="heading"]');

    headings.each((index, element) => {
      const $heading = $(element);
      const className = $heading.attr("class") || "";

      const levelMatch = className.match(/docx-heading(\d+)-block|heading(\d+)/);
      if (!levelMatch) return;

      const level = parseInt(levelMatch[1] || levelMatch[2]);
      const text = $heading.text().trim();
      if (!text) return;

      const headingId = `heading-${nodeId}-${index}`;
      $heading.attr("id", headingId);

      const headingNode: HeadingNode = {
        id: headingId,
        text,
        level,
        children: [],
      };

      insertHeadingIntoTree(headingNode, headingTree);
    });

    // 更新HTML内容
    contentNodes.set(nodeId, $.html());
  }

  return { headingTree, contentNodes };
}

function generateTOC(headingTree: HeadingNode[]): string {
  if (headingTree.length === 0) return "";

  const generateTOCItems = (
    headings: HeadingNode[],
    level: number = 0,
  ): string => {
    return headings
      .map((heading) => {
        const indent = level * 20;
        const children =
          heading.children.length > 0
            ? generateTOCItems(heading.children, level + 1)
            : "";

        return `
          <div class="toc-item" style="margin-left: ${indent}px;">
            <a href="#${heading.id}" class="toc-link">${heading.text}</a>
            ${children}
          </div>
        `;
      })
      .join("");
  };

  return `
      <div class="toc-container">
        <h2 class="toc-title">目录</h2>
        <div class="toc-content">
          ${generateTOCItems(headingTree)}
        </div>
      </div>
    `;
}

async function htmlGenerator({
  contentNodes,
  title,
  styleHTML,
  downloadDir,
}: {
  contentNodes: Map<string, string>;
  title: string;
  styleHTML: string;
  downloadDir: string;
}) {
  // Keep behavior identical to the original HTMLGenerator.ts
  styleHTML = "";

  initDownloadDir(downloadDir);

  const filePath = `${downloadDir}/${title}.html`;
  const writeStream = fs.createWriteStream(filePath);
  let headingTree: HeadingNode[] = [];

  ({ headingTree, contentNodes } = extractHeadings(contentNodes));

  const tocHTML = generateTOC(headingTree);
  const navigationHTML = generateNavigation(headingTree);

  const templatePath = path.join(here, "src", "assets", "template.html");
  const template = fs.readFileSync(templatePath, "utf-8");

  const processedTemplate = template
    .replace("{{STYLES}}", styleHTML)
    .replace("{{TITLE}}", title)
    .replace("{{TOC}}", tocHTML)
    .replace("{{NAVIGATION}}", navigationHTML);

  const [headPart, tailPart] = processedTemplate.split("{{CONTENT}}");

  writeStream.write(headPart);

  const contentStream = new Readable({
    read() {
      for (const [, html] of contentNodes) {
        this.push(html);
      }
      this.push(null);
    },
  });

  // Attach metadata to keep parity with the original code.
  (contentStream as any).contentNodes = contentNodes;

  await new Promise<void>((resolve, reject) => {
    contentStream.pipe(writeStream, { end: false });
    contentStream.on("end", () => {
      writeStream.end(tailPart);
      resolve();
    });
    contentStream.on("error", reject);
    writeStream.on("error", reject);
  });

  return filePath;
}

export class FeishuDocScraper {
  private browser!: Browser;
  private config!: ScrollerConfig;
  private contentNodes = new Map<string, string>();
  private logger = console;
  private styleHTML = "";
  private title = "doc";

  constructor(
    private docType: DocType = "fs-doc",
    private opts?: {
      logger?: Console;
    },
  ) {
    if (opts?.logger) this.logger = opts.logger;
  }

  async initialize(options?: { debug?: boolean }) {
    const debug = options?.debug ?? false;
    const launchOpts = debug ? { headless: false, devtools: true } : {};
    this.browser = await chromium.launch(launchOpts);
    this.configure();
    this.logger.info("Scraper initialized");
  }

  private configure() {
    const baseConfig = {
      navSelector: ".catalogue li a",
      placeholderSelectors: ["[class*=placeholder]", ".isEmpty"],
      initialScrollText: "开始讲课",
      scrollGap: 800,
      scrollInterval: 800,
      getNodeId: (node: Element) => node.getAttribute("id"),
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
      "fs-doc": {
        scrollContainer: "html",
        contentContainer:
          '.page-block-children > .virtual-list > [role="group"]',
        nodeAttribute: "role",
        getNodeId: async (node: ElementHandle) => {
          const classList = await node.getAttribute("class");
          return (
            classList?.match(/item-([a-zA-Z0-9]+) listitem/)?.[1] ?? null
          );
        },
      },
    };

    this.config = {
      ...baseConfig,
      ...typeConfigs[this.docType],
    } as ScrollerConfig;
  }

  async process(options: ProcessOptions) {
    const { url, cookies, localStorage, timeout = 30000 } = options;

    const context = await this.createAuthContext(url, cookies, localStorage);
    context.addInitScript({
      content: injectJs,
    });
    const page = await context.newPage();

    try {
      await page.goto(url, { waitUntil: "networkidle", timeout });
      await this.handleInitialNavigation(page);

      this.styleHTML = (
        await Promise.all(
          Array.from(await page.$$("style")).map(async (node) => {
            return await node.evaluate((n) => (n as any).outerHTML);
          }),
        )
      ).join("\n");

      this.title = await page.evaluate(() => document.title);
      await this.collectContent(page);
      await this.processImages(page);

      return {
        contentNodes: this.contentNodes,
        title: this.title,
        styleHTML: this.styleHTML,
      };
    } finally {
      await context.close();
    }
  }

  private async createAuthContext(
    url: string,
    cookies?: BrowserContextCookie[],
    localStorage?: Record<string, string>,
  ): Promise<BrowserContext> {
    const context = await this.browser.newContext({
      storageState: {
        cookies: (cookies ?? []).map((item) =>
          omit(item, ["sameSite"]) as any,
        ),
        origins: [
          {
            origin: new URL(url).origin,
            localStorage: Object.entries(localStorage ?? {}).map(
              ([key, value]) => ({ name: key, value }),
            ),
          },
        ],
      },
    });

    if (cookies?.length) this.logger.debug(`Added ${cookies.length} cookies`);
    if (localStorage) {
      this.logger.debug(
        `Added ${Object.keys(localStorage).length} localStorage items`,
      );
    }

    return context;
  }

  private async handleInitialNavigation(page: Page) {
    try {
      const navItem = await page.waitForSelector(
        `${this.config.navSelector} >> text=${this.config.initialScrollText}`,
        { timeout: 5000 },
      );

      await navItem.click();
      await page.waitForTimeout(2000);
      this.logger.info("Initial navigation completed");
    } catch {
      this.logger.warn(
        "Initial navigation target not found, using default position",
      );
    }
  }

  private async collectContent(page: Page) {
    let lastSize = 0;
    let sameCount = 0;
    const maxRetries = 10;

    while (sameCount < maxRetries && this.contentNodes.size < MAX_CONTENT_NODES) {
      await this.scrollPage(page);
      try {
        await this.captureNodes(page);
      } catch (error) {
        this.logger.error(error);
      }

      if (this.contentNodes.size === lastSize) {
        sameCount++;
        this.logger.debug(
          `No new content detected (${sameCount}/${maxRetries})`,
        );
      } else {
        lastSize = this.contentNodes.size;
        sameCount = 0;
      }
    }

    this.logger.info(`Collected ${this.contentNodes.size} content nodes`);
  }

  private async scrollPage(page: Page) {
    await page.evaluate(
      ({ scrollGap }) => {
        window.scrollBy({ top: scrollGap, behavior: "smooth" });
      },
      { scrollGap: this.config.scrollGap },
    );
    await page.waitForTimeout(this.config.scrollInterval);
  }

  private async captureNodes(page: Page) {
    const nodes = await page.$$(`${this.config.contentContainer} > *`);

    for (const nodeHandle of nodes) {
      const nodeId = await this.config.getNodeId(nodeHandle);

      if (!nodeId) continue;

      const html = await nodeHandle.evaluate((node) => {
        (node as Element)
          .querySelectorAll("[aria-hidden]")
          .forEach((el) => el.remove());
        return (node as Element).outerHTML;
      });

      if (!this.contentNodes.has(nodeId) || this.contentNodes.get(nodeId) !== html) {
        this.contentNodes.set(nodeId, html);
        this.logger.debug(`Captured node: ${nodeId}`);
      }
    }
  }

  private async processImages(page: Page) {
    const nodeEntries = Array.from(this.contentNodes.entries());

    await Promise.all(
      nodeEntries.map(async ([nodeId, html]) => {
        const $ = load(html);
        const imgElements = $("img").toArray();

        for (const img of imgElements) {
          const $img = $(img);
          const src = $img.attr("src");
          if (!src) continue;

          try {
            const base64 = await page.evaluate(async (s) => {
              return (window as any).convertToBase64(s);
            }, src);

            $img.attr("src", base64);
          } catch (error: any) {
            this.logger.error(`[${nodeId}] 图片处理失败: ${src}`, error);
            $img.attr("data-error", error?.message ?? String(error));
          }
        }

        this.contentNodes.set(nodeId, $.html());
      }),
    );
  }

  async close() {
    await this.browser.close();
  }
}

const getTitleAndContentNodes = async (file: string) => {
  return new Promise<{
    contentNodes: Map<string, string>;
    styleHTML: string;
  }>((resolve, reject) => {
    const readStream = fs.createReadStream(file, { encoding: "utf8" });
    const contentNodes = new Map<string, string>();
    const styles: string[] = [];
    let contentNodeId: string | null = null;
    let contentNode = "";
    let isInContentNode = false;
    let depth = 0;
    let styleHTML = "";
    let isInStyleTag = false;

    const parser = new Parser(
      {
        onopentag(name, attrs) {
          name = name.toLowerCase();

          if (name === "style") {
            isInStyleTag = true;
            styleHTML = `<style`;
            if (attrs) {
              Object.entries(attrs).forEach(([key, value]) => {
                styleHTML += ` ${key}="${value}"`;
              });
            }
            styleHTML += ">";
          } else if (
            name === "div" &&
            (attrs as any).role === "listitem" &&
            (attrs as any).class?.includes("item-")
          ) {
            const match = /item-([a-zA-Z0-9]{4,})/.exec(
              (attrs as any).class,
            );
            if (match) {
              contentNodeId = match[1];
              isInContentNode = true;
              contentNode = "";
              depth = 1;
            }
          } else if (isInContentNode) {
            depth++;
            contentNode += `<${name}`;
            if (attrs) {
              Object.entries(attrs).forEach(([key, value]) => {
                contentNode += ` ${key}="${value}"`;
              });
            }
            contentNode += ">";
          }
        },
        ontext(text) {
          if (isInStyleTag) styleHTML += text;
          else if (isInContentNode && contentNodeId) contentNode += text;
        },
        onclosetag(name) {
          if (name === "style" && isInStyleTag) {
            styleHTML += "</style>";
            styles.push(styleHTML);
            isInStyleTag = false;
            styleHTML = "";
          } else if (isInContentNode && contentNodeId) {
            if (name === "div" && depth === 1) {
              const cleanedContent = contentNode.trim();
              if (cleanedContent) {
                contentNodes.set(contentNodeId, cleanedContent);
              }
              isInContentNode = false;
              contentNodeId = null;
              contentNode = "";
              depth = 0;
            } else if (isInContentNode) {
              depth--;
              contentNode += `</${name}>`;
            }
          }
        },
        onend() {
          resolve({ contentNodes, styleHTML: styles.join("\n") });
        },
        onerror(err) {
          reject(err);
        },
      },
      { decodeEntities: false },
    );

    readStream.on("data", (chunk) => {
      try {
        parser.write(chunk.toString());
      } catch (err) {
        reject(err);
      }
    });
    readStream.on("end", () => {
      try {
        parser.end();
      } catch (err) {
        reject(err);
      }
    });
    readStream.on("error", (err) => reject(err));
  });
};

async function convertDir(dir: string, outDir: string) {
  const files = fs.readdirSync(dir);
  const htmlFiles = files.filter((file) => file.endsWith(".html"));
  console.log(`Found ${htmlFiles.length} HTML files in directory: ${dir}`);

  for (const file of htmlFiles) {
    const filePath = path.join(dir, file);
    try {
      const { contentNodes, styleHTML } = await getTitleAndContentNodes(filePath);
      const title = file.replace(/\.html$/, "");
      await htmlGenerator({
        contentNodes,
        styleHTML,
        title,
        downloadDir: outDir,
      });
      console.log(`Processed ${file}`);
    } catch (error) {
      console.error(`Error processing ${file}:`, error);
    }
  }
}

function parseArgs(argv: string[]) {
  const args: Record<string, string | boolean> = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith("--")) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    }
  }
  return args;
}

async function runScrape({
  configPath,
  docType,
  downloadDir,
}: {
  configPath: string;
  docType: DocType;
  downloadDir: string;
}) {
  const config = loadJson(configPath);
  const scraper = new FeishuDocScraper(docType);

  try {
    await scraper.initialize({ debug: Boolean(config?.debug) });
    const result = await scraper.process(config as any);
    const filePath = await htmlGenerator({
      ...result,
      downloadDir,
    });
    console.log("Processed Path:\n", filePath);
  } catch (error) {
    console.error("Scraping failed:", error);
  } finally {
    await scraper.close();
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const defaultConfigPath = path.join(here, "config.json");
  const docType = (args.docType as string) as DocType | undefined;
  const downloadDir = (args.downloadDir as string) || "downloads";

  const configPath = (args.config as string) || defaultConfigPath;

  const shouldConvert = Boolean(args.convertDir || args.convert);
  if (shouldConvert) {
    const dir = (args.convertDir as string) || (args.dir as string) || "downloads";
    const outDir = (args.outDir as string) || "downloads2";
    await convertDir(dir, outDir);
    return;
  }

  // Default action: scrape (parity with src/main.ts)
  const type: DocType = docType || "fs-doc";
  await runScrape({ configPath, docType: type, downloadDir });
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

