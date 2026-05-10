import config from "../config.json";
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

function resolveUrls(cfg: ScraperConfigJson): string[] {
    if (Array.isArray(cfg.urls) && cfg.urls.length > 0) {
        return cfg.urls.filter((u) => typeof u === "string" && u.trim().length > 0);
    }
    if (cfg.url && cfg.url.trim().length > 0) {
        return [cfg.url.trim()];
    }
    return [];
}

async function main() {
    const cfg = config as ScraperConfigJson;
    const urls = resolveUrls(cfg);
    const maxConcurrency = Math.max(1, cfg.maxConcurrency ?? 3);
    const downloadDir = (cfg.downloadDir?.trim() || "downloads").replace(/\/+$/, "") || "downloads";

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