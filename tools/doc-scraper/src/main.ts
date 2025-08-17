import config from "../config.json";
import { FeishuDocScraper } from "./DocScraper";
import { htmlGenerator } from "./HTMLGenerator";

// 使用示例
async function main() {
    const scraper = new FeishuDocScraper("fs-doc");

    try {
        await scraper.initialize();

        const result = await scraper.process(config as any);
        const filePath = await htmlGenerator({
            ...result,
            downloadDir: 'downloads'
        });

        console.log("Processed Path:\n", filePath);
    } catch (error) {
        console.error("Scraping failed:", error);
    } finally {
        await scraper.close();
    }
}

main();