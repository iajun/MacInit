import { chromium, ElementHandle, type Browser, type BrowserContext, type Page } from 'playwright';
import fs from 'fs'
import { load } from 'cheerio'

type DocType = 'docx' | 'doc' | 'fs-doc';

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

type ExtractPromise<T> = T extends Promise<infer U> ? U : never

type BrowserContextCookie = ExtractPromise<ReturnType<BrowserContext['storageState']>>['cookies'][number]

interface ProcessOptions {
  url: string;
  cookies?: BrowserContextCookie[];
  localStorage?: Record<string, string>;
  timeout?: number;
}

class FeishuDocScraper {
  private browser!: Browser;
  private config!: ScrollerConfig;
  private contentNodes = new Map<string, string>();
  private logger = console;
  private styleHTML = ''
  private title = 'doc'
  private downloadDir = 'downloads'

  constructor(private docType: DocType = 'fs-doc') { }

  async initialize() {
    this.browser = await chromium.launch({ headless: true, devtools: true });
    this.configure();
    this.logger.info('Scraper initialized');
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
      getNodeId: (node: Element) => node.getAttribute('id'),
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
      'fs-doc': {
        scrollContainer: "html",
        contentContainer: '.page-block-children > .virtual-list > [role="group"]',
        nodeAttribute: "role",
        getNodeId: async (node: ElementHandle) => {
          const classList = await node.getAttribute('class')
          return classList?.match(/item-([a-zA-Z0-9]+) listitem/)?.[1] ?? null;
        }
      }
    };

    this.config = {
      ...baseConfig,
      ...typeConfigs[this.docType]
    } as ScrollerConfig;
  }

  async process(options: ProcessOptions) {
    const { url, cookies, localStorage, timeout = 30000 } = options;
    const context = await this.createAuthContext(url, cookies, localStorage);
    context.addInitScript({ content: fs.readFileSync('./src/inject.js', 'utf-8') });
    const page = await context.newPage();

    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout });
      await this.handleInitialNavigation(page);
      this.styleHTML = (await Promise.all(Array.from(await page.$$('style')).map(async (node) => await node.evaluate(node => node.outerHTML)))).join('\n');
      this.title = await page.evaluate(() => document.title);
      await this.collectContent(page);
      await this.processImages(page);
      return this.generateFinalContent(page);
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
        cookies: cookies ?? [],
        origins: [
          {
            origin: new URL(url).origin,
            localStorage: Object.entries(localStorage ?? {}).map(([key, value]) => ({ name: key, value }))
          }
        ]
      }
    });

    if (cookies?.length) {
      this.logger.debug(`Added ${cookies.length} cookies`);
    }

    if (localStorage) {
      this.logger.debug(`Added ${Object.keys(localStorage).length} localStorage items`);
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
      this.logger.info('Initial navigation completed');
    } catch (error) {
      this.logger.warn('Initial navigation target not found, using default position');
    }
  }

  private async collectContent(page: Page) {
    let lastSize = 0;
    let sameCount = 0;
    const maxRetries = 15;

    while (sameCount < maxRetries) {
      await this.scrollPage(page);
      try {
        await this.captureNodes(page);
      } catch (error) {
        this.logger.error(error)
      }
      if (this.contentNodes.size > 50) break;

      if (this.contentNodes.size === lastSize) {
        sameCount++;
        this.logger.debug(`No new content detected (${sameCount}/${maxRetries})`);
      } else {
        lastSize = this.contentNodes.size;
        sameCount = 0;
      }
    }

    this.logger.info(`Collected ${this.contentNodes.size} content nodes`);
  }

  private async scrollPage(page: Page) {
    await page.evaluate(({ scrollGap }) => {
      window.scrollBy({ top: scrollGap, behavior: 'smooth' });
    }, { scrollGap: this.config.scrollGap });

    await page.waitForTimeout(this.config.scrollInterval);
  }

  private async captureNodes(page: Page) {
    const nodes = await page.$$(`${this.config.contentContainer} > *`);

    for (const nodeHandle of nodes) {
      const nodeId = await this.config.getNodeId(nodeHandle);

      if (nodeId) {
        const html = await nodeHandle.evaluate(node => {
          node.querySelectorAll('[aria-hidden]').forEach(el => el.remove());
          return node.outerHTML;
        });

        if (!this.contentNodes.has(nodeId) || this.contentNodes.get(nodeId) !== html) {
          this.contentNodes.set(nodeId, html);
          this.logger.debug(`Captured node: ${nodeId}`);
        }
      }
    }
  }

  private async processImages(page: Page) {
    const nodeEntries = Array.from(this.contentNodes.entries());

    // 并行处理所有节点的图片
    await Promise.all(nodeEntries.map(async ([nodeId, html]) => {
      const $ = load(html);
      const imgElements = $('img').toArray();

      // 串行处理单节点内的图片
      for (const img of imgElements) {
        const $img = $(img);
        const src = $img.attr('src');

        if (!src) continue;

        try {
          // 在浏览器上下文执行转换
          const base64 = await page.evaluate(async (src) => {
            return (window as any).convertToBase64(src)
          }, src);

          $img.attr('src', base64);
        } catch (error) {
          this.logger.error(`[${nodeId}] 图片处理失败: ${src}`, error);
          $img.attr('data-error', error.message);
        }
      }

      this.contentNodes.set(nodeId, $.html());
    }))
  }

  private async generateFinalContent(page: Page) {
    const contentHTML = Array.from(this.contentNodes.values()).join('');

    const finalHTML = `
      <html>
        <head>
        ${this.styleHTML}
        </head>
        <body>
          <div style="max-width: 800px; margin: auto;">
          ${contentHTML}
          </div>
        </body>
      </html>
    `;

    fs.writeFileSync(`${this.downloadDir}/${this.title}.html`, finalHTML);
    return finalHTML;
  }

  async close() {
    await this.browser.close();
  }
}

// 使用示例
async function main() {
  const scraper = new FeishuDocScraper('fs-doc');

  try {
    await scraper.initialize();

    const result = await scraper.process(require('../config.json'));

    console.log('Processed Content:\n', result);
  } catch (error) {
    console.error('Scraping failed:', error);
  } finally {
    await scraper.close();
  }
}

main();