import {
  chromium,
  ElementHandle,
  type Browser,
  type BrowserContext,
  type Page,
} from "playwright";
import fs from "fs";
import { load } from "cheerio";
import { Readable } from "stream";
import config from "../config.json";
import { omit } from "lodash-es";

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

interface HeadingNode {
  id: string;
  text: string;
  level: number;
  children: HeadingNode[];
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

class FeishuDocScraper {
  private browser!: Browser;
  private config!: ScrollerConfig;
  private contentNodes = new Map<string, string>();
  private headingTree: HeadingNode[] = [];
  private logger = console;
  private styleHTML = "";
  private title = "doc";
  private downloadDir = "downloads";

  constructor(private docType: DocType = "fs-doc") { }

  async initialize() {
    let opts = config.debug ? { headless: false, devtools: true } : {};
    this.browser = await chromium.launch(opts);
    this.configure();
    this.logger.info("Scraper initialized");
    this.initDownloadDir();
  }

  private initDownloadDir() {
    if (!fs.existsSync(this.downloadDir)) {
      fs.mkdirSync(this.downloadDir);
    }
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
          return classList?.match(/item-([a-zA-Z0-9]+) listitem/)?.[1] ?? null;
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
      content: fs.readFileSync("./src/inject.js", "utf-8"),
    });
    const page = await context.newPage();

    try {
      await page.goto(url, { waitUntil: "networkidle", timeout });
      await this.handleInitialNavigation(page);
      this.styleHTML = (
        await Promise.all(
          Array.from(await page.$$("style")).map(
            async (node) => await node.evaluate((node) => node.outerHTML)
          )
        )
      ).join("\n");
      this.title = await page.evaluate(() => document.title);
      await this.collectContent(page);
      await this.processImages(page);
      return this.generateFinalContent();
    } finally {
      await context.close();
      this.contentNodes.clear();
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

  private async handleInitialNavigation(page: Page) {
    try {
      const navItem = await page.waitForSelector(
        `${this.config.navSelector} >> text=${this.config.initialScrollText}`,
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
          `No new content detected (${sameCount}/${maxRetries})`
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
      { scrollGap: this.config.scrollGap }
    );

    await page.waitForTimeout(this.config.scrollInterval);
  }

  private async captureNodes(page: Page) {
    const nodes = await page.$$(`${this.config.contentContainer} > *`);

    for (const nodeHandle of nodes) {
      const nodeId = await this.config.getNodeId(nodeHandle);

      if (nodeId) {
        const html = await nodeHandle.evaluate((node) => {
          node.querySelectorAll("[aria-hidden]").forEach((el) => el.remove());
          return node.outerHTML;
        });

        if (
          !this.contentNodes.has(nodeId) ||
          this.contentNodes.get(nodeId) !== html
        ) {
          this.contentNodes.set(nodeId, html);
          this.logger.debug(`Captured node: ${nodeId}`);
        }
      }
    }
  }

  private extractHeadings() {
    this.headingTree = [];
    
    for (const [nodeId, html] of this.contentNodes) {
      const $ = load(html);
      
      // 查找所有标题元素
      const headings = $('[class*="docx-heading"], [class*="heading"]');
      
      headings.each((index, element) => {
        const $heading = $(element);
        const className = $heading.attr('class') || '';
        
        // 提取标题级别
        const levelMatch = className.match(/docx-heading(\d+)-block|heading(\d+)/);
        if (levelMatch) {
          const level = parseInt(levelMatch[1] || levelMatch[2]);
          const text = $heading.text().trim();
          
          if (text) {
            const headingId = `heading-${nodeId}-${index}`;
            
            // 为标题添加锚点ID
            $heading.attr('id', headingId);
            
            // 构建标题节点
            const headingNode: HeadingNode = {
              id: headingId,
              text,
              level,
              children: []
            };
            
            // 将标题插入到标题树中
            this.insertHeadingIntoTree(headingNode);
          }
        }
      });
      
      // 更新HTML内容
      this.contentNodes.set(nodeId, $.html());
    }
    
    this.logger.info(`Extracted ${this.headingTree.length} headings`);
  }

  private insertHeadingIntoTree(heading: HeadingNode) {
    if (this.headingTree.length === 0) {
      this.headingTree.push(heading);
      return;
    }
    
    // 找到合适的父级标题
    let currentLevel = 0;
    let currentPath: HeadingNode[] = [this.headingTree[0]];
    
    for (let i = 1; i < this.headingTree.length; i++) {
      const node = this.headingTree[i];
      
      if (node.level < heading.level) {
        // 当前节点级别更低，可以作为父级
        currentLevel = node.level;
        currentPath = this.headingTree.slice(0, i + 1);
      } else if (node.level === heading.level) {
        // 同级标题，添加到同级
        currentPath = this.headingTree.slice(0, i);
        break;
      } else {
        // 当前节点级别更高，停止搜索
        break;
      }
    }
    
    // 找到最终的父级容器
    let parent = currentPath[currentPath.length - 1];
    while (parent.children.length > 0 && parent.children[parent.children.length - 1].level < heading.level) {
      parent = parent.children[parent.children.length - 1];
    }
    
    if (parent.level < heading.level) {
      parent.children.push(heading);
    } else {
      // 如果没有合适的父级，添加到根级别
      this.headingTree.push(heading);
    }
  }

  private generateTOC(): string {
    if (this.headingTree.length === 0) {
      return '';
    }
    
    const generateTOCItems = (headings: HeadingNode[], level: number = 0): string => {
      return headings.map(heading => {
        const indent = level * 20;
        const children = heading.children.length > 0 ? generateTOCItems(heading.children, level + 1) : '';
        
        return `
          <div class="toc-item" style="margin-left: ${indent}px;">
            <a href="#${heading.id}" class="toc-link">${heading.text}</a>
            ${children}
          </div>
        `;
      }).join('');
    };
    
    return `
      <div class="toc-container">
        <h2 class="toc-title">目录</h2>
        <div class="toc-content">
          ${generateTOCItems(this.headingTree)}
        </div>
      </div>
    `;
  }

  private generateNavigation(): string {
    if (this.headingTree.length === 0) {
      return '';
    }
    
    const generateNavItems = (headings: HeadingNode[]): string => {
      return headings.map(heading => {
        const children = heading.children.length > 0 ? generateNavItems(heading.children) : '';
        
        return `
          <li class="nav-item nav-level-${heading.level}">
            <a href="#${heading.id}" class="nav-link">${heading.text}</a>
            ${children ? `<ul class="nav-children">${children}</ul>` : ''}
          </li>
        `;
      }).join('');
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
          ${generateNavItems(this.headingTree)}
        </ul>
      </nav>
    `;
  }

  private async processImages(page: Page) {
    const nodeEntries = Array.from(this.contentNodes.entries());

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

            $img.attr("src", base64);
          } catch (error) {
            this.logger.error(`[${nodeId}] 图片处理失败: ${src}`, error);
            $img.attr("data-error", error.message);
          }
        }

        this.contentNodes.set(nodeId, $.html());
      })
    );
  }

  private async generateFinalContent() {
    // 在生成最终内容前提取标题
    this.extractHeadings();
    
    const filePath = `${this.downloadDir}/${this.title}.html`;
    const writeStream = fs.createWriteStream(filePath);

    // 读取模板文件
    const templatePath = "./src/assets/template.html";
    const template = fs.readFileSync(templatePath, "utf-8");

    // 生成TOC和导航
    const tocHTML = this.generateTOC();
    const navigationHTML = this.generateNavigation();

    // 替换模板中的占位符
    const processedTemplate = template
      .replace("{{STYLES}}", this.styleHTML)
      .replace("{{TITLE}}", this.title)
      .replace("{{TOC}}", tocHTML)
      .replace("{{NAVIGATION}}", navigationHTML);

    // 分割模板为头部和尾部
    const [headPart, tailPart] = processedTemplate.split("{{CONTENT}}");

    // 写入头部
    writeStream.write(headPart);

    // 创建内容流
    const contentStream = new Readable({
      read() {
        // 将 contentNodes 分块推送
        for (const [nodeId, html] of (this as any).contentNodes) {
          this.push(html);
        }
        this.push(null);
      }
    });

    // 设置 contentNodes 到流中
    (contentStream as any).contentNodes = this.contentNodes;

    // 通过管道连接内容流和写入流
    await new Promise<void>((resolve, reject) => {
      contentStream.pipe(writeStream, { end: false });

      contentStream.on("end", () => {
        // 写入尾部
        writeStream.end(tailPart);
        resolve();
      });

      contentStream.on("error", reject);
      writeStream.on("error", reject);
    });

    return filePath;
  }

  async close() {
    await this.browser.close();
  }
}

// 使用示例
async function main() {
  const scraper = new FeishuDocScraper("fs-doc");

  try {
    await scraper.initialize();

    const result = await scraper.process(config as any);

    console.log("Processed Content:\n", result);
  } catch (error) {
    console.error("Scraping failed:", error);
  } finally {
    await scraper.close();
  }
}

main();
