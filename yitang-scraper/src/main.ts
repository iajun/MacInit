import fs from "fs";
import path from "path";
import {
  captureAuth,
  configHasAuth,
  DEFAULT_CONFIG_PATH,
} from "./captureAuth";
import { FeishuDocScraper } from "./DocScraper";
import { htmlGenerator } from "./HTMLGenerator";
import { isYitangLessonSectionUrl } from "./lessonSectionUrl";
import { runPool } from "./runPool";

type ScraperConfigJson = {
  url?: string;
  urls?: string[];
  maxConcurrency?: number;
  /** Directory where scraped HTML files are written (relative to cwd or absolute). */
  downloadDir?: string;
  cookies?: unknown;
  localStorage?: Record<string, string>;
  timeout?: number;
  debug?: boolean;
};

function looksLikeUrl(value: string): boolean {
  return /^https?:\/\//i.test(value);
}

function parseArgs(argv: string[]) {
  let forceAuth = false;
  let url: string | undefined;
  let configPath = DEFAULT_CONFIG_PATH;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--auth") {
      forceAuth = true;
    } else if (arg === "--url" && argv[i + 1]) {
      url = argv[++i];
    } else if (arg === "--config" && argv[i + 1]) {
      configPath = path.resolve(argv[++i]);
    } else if (arg === "--help" || arg === "-h") {
      console.log(`Usage: pnpm start [url] [--auth] [--url <url>] [--config <path>]

  pnpm start <url>   Scrape a single URL (opens browser login if needed)
  --auth             Re-open browser and refresh cookies / localStorage first
`);
      process.exit(0);
    } else if (!arg.startsWith("-") && looksLikeUrl(arg)) {
      url = arg;
    } else {
      console.error(`Unknown argument: ${arg}`);
      process.exitCode = 1;
      process.exit(1);
    }
  }
  return { forceAuth, url, configPath };
}

function loadConfig(configPath: string): ScraperConfigJson {
  if (!fs.existsSync(configPath)) {
    return {};
  }
  return JSON.parse(fs.readFileSync(configPath, "utf-8")) as ScraperConfigJson;
}

function resolveUrls(cfg: ScraperConfigJson, overrideUrl?: string): string[] {
  if (overrideUrl?.trim()) {
    return [overrideUrl.trim()];
  }
  if (Array.isArray(cfg.urls) && cfg.urls.length > 0) {
    return cfg.urls.filter((u) => typeof u === "string" && u.trim().length > 0);
  }
  if (cfg.url && cfg.url.trim().length > 0) {
    return [cfg.url.trim()];
  }
  return [];
}

async function main() {
  const { forceAuth, url: overrideUrl, configPath } = parseArgs(
    process.argv.slice(2)
  );

  let cfg = loadConfig(configPath);

  if (forceAuth || !configHasAuth(cfg)) {
    console.log(
      forceAuth
        ? "Refreshing auth via browser…"
        : "config 中缺少 cookie / localStorage，开始浏览器登录捕获…"
    );
    await captureAuth({
      url: overrideUrl || cfg.url || cfg.urls?.[0],
      configPath,
    });
    cfg = loadConfig(configPath);
  }

  const urls = resolveUrls(cfg, overrideUrl);
  const maxConcurrency = Math.max(1, cfg.maxConcurrency ?? 3);
  const downloadDir =
    (cfg.downloadDir?.trim() || "downloads").replace(/\/+$/, "") || "downloads";

  if (urls.length === 0) {
    console.error("config.json: set `url` or non-empty `urls` array.");
    process.exitCode = 1;
    return;
  }

  const scraper = new FeishuDocScraper();

  try {
    await scraper.initialize();
    console.log(
      `Scraping ${urls.length} URL(s), maxConcurrency=${maxConcurrency}, downloadDir=${downloadDir}`
    );

    await runPool(urls, maxConcurrency, async (url, index) => {
      try {
        const result = isYitangLessonSectionUrl(url)
          ? await scraper.processLessonSections({
              url,
              cookies: cfg.cookies as any,
              localStorage: cfg.localStorage,
              timeout: cfg.timeout,
            })
          : await scraper.process({
              url,
              cookies: cfg.cookies as any,
              localStorage: cfg.localStorage,
              timeout: cfg.timeout,
            });
        const filePath = await htmlGenerator({
          ...result,
          downloadDir,
        });
        console.log(`[${index + 1}/${urls.length}] OK ${url}\n  -> ${filePath}`);
      } catch (error) {
        console.error(`[${index + 1}/${urls.length}] FAILED ${url}`, error);
      }
    });
  } catch (error) {
    console.error("Scraping failed:", error);
  } finally {
    await scraper.close();
  }
}

main();
