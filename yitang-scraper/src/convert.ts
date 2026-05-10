import fs from "fs";
import os from "os";
import path from "path";
import { Parser } from "htmlparser2";
import { getDir } from "./utils";

interface HeadingNode {
    id: string;
    text: string;
    level: number;
    children: HeadingNode[];
}

function sanitizeFileName(input: string, fallbackBaseName: string = "untitled"): string {
    const replaced = input
        .replace(/[\u0000-\u001F\u007F]/g, "")
        .replace(/[<>:"/\\|?*]/g, "／")
        .replace(/[:]/g, "：")
        .replace(/\s+/g, " ")
        .trim()
        .replace(/[. ]+$/g, "");

    const base = replaced.length > 0 ? replaced : fallbackBaseName;
    if (/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$/i.test(base)) {
        return `_${base}`.slice(0, 180);
    }
    return base.slice(0, 180);
}

function insertHeadingIntoTree(heading: HeadingNode, headingTree: HeadingNode[]) {
    if (headingTree.length === 0) {
        headingTree.push(heading);
        return;
    }

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
    while (parent.children.length > 0 && parent.children[parent.children.length - 1].level < heading.level) {
        parent = parent.children[parent.children.length - 1];
    }

    if (parent.level < heading.level) parent.children.push(heading);
    else headingTree.push(heading);
}

function generateNavigation(headingTree: HeadingNode[]): string {
    if (headingTree.length === 0) return "";

    const generateNavItems = (headings: HeadingNode[]): string =>
        headings
            .map((heading) => {
                const children = heading.children.length > 0 ? generateNavItems(heading.children) : "";
                return `
          <li class="nav-item nav-level-${heading.level}">
            <a href="#${heading.id}" class="nav-link">${heading.text}</a>
            ${children ? `<ul class="nav-children">${children}</ul>` : ""}
          </li>
        `;
            })
            .join("");

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

function generateTOC(headingTree: HeadingNode[]): string {
    if (headingTree.length === 0) return "";

    const generateTOCItems = (headings: HeadingNode[], level: number = 0): string =>
        headings
            .map((heading) => {
                const indent = level * 20;
                const children = heading.children.length > 0 ? generateTOCItems(heading.children, level + 1) : "";
                return `
          <div class="toc-item" style="margin-left: ${indent}px;">
            <a href="#${heading.id}" class="toc-link">${heading.text}</a>
            ${children}
          </div>
        `;
            })
            .join("");

    return `
      <div class="toc-container">
        <h2 class="toc-title">目录</h2>
        <div class="toc-content">
          ${generateTOCItems(headingTree)}
        </div>
      </div>
    `;
}

function stripTags(html: string): string {
    return html
        .replace(/<script[\s\S]*?<\/script>/gi, "")
        .replace(/<style[\s\S]*?<\/style>/gi, "")
        .replace(/<[^>]+>/g, " ")
        .replace(/\s+/g, " ")
        .trim();
}

function injectHeadingIdsAndCollect(
    html: string,
    blockKey: string,
    headingTree: HeadingNode[],
    startIndex: number,
    opts?: {
        stopAtHeadingText?: (headingText: string, level: number) => boolean;
    }
): { html: string; nextIndex: number; stopped: boolean } {
    let idx = startIndex;
    let stopped = false;
    const STOP_MARKER = "<!--DOC_SCRAPER_STOP-->";

    // Match elements with a class containing heading info; keep it conservative to avoid runaway regex.
    const re =
        /<([a-zA-Z0-9]+)([^>]*\bclass\s*=\s*"[^"]*(?:docx-heading(\d+)-block|heading(\d+))[^"]*"[^>]*)>([\s\S]*?)<\/\1>/g;

    const replaced = html.replace(re, (full, tagName, attrs, lv1, lv2, inner) => {
        if (stopped) return "";
        const level = parseInt(lv1 || lv2, 10);
        if (!Number.isFinite(level) || level <= 0) return full;

        const headingId = `heading-${blockKey}-${idx++}`;
        const text = stripTags(inner);

        if (text && opts?.stopAtHeadingText?.(text, level)) {
            stopped = true;
            return STOP_MARKER;
        }

        if (text) {
            const headingNode: HeadingNode = { id: headingId, text, level, children: [] };
            insertHeadingIntoTree(headingNode, headingTree);
        }

        // If id already exists, don't override.
        if (/\bid\s*=/.test(attrs)) return full;
        return `<${tagName}${attrs} id="${headingId}">${inner}</${tagName}>`;
    });

    if (!stopped) return { html: replaced, nextIndex: idx, stopped: false };

    const cutAt = replaced.indexOf(STOP_MARKER);
    const truncated = cutAt >= 0 ? replaced.slice(0, cutAt) : replaced;
    return { html: truncated, nextIndex: idx, stopped: true };
}

async function streamExtractAndWriteContent({
    file,
    contentWriteStream,
}: {
    file: string;
    contentWriteStream: fs.WriteStream;
}): Promise<{ styleHTML: string; headingTree: HeadingNode[] }> {
    return new Promise((resolve, reject) => {
        const readStream = fs.createReadStream(file, { encoding: "utf8" });

        const styles: string[] = [];
        let styleHTML = "";
        let isInStyleTag = false;

        let isInContentNode = false;
        let depth = 0;
        let contentNode = "";
        let contentNodeKey: string | null = null;
        let contentNodeIndex = 0;
        let headingIndex = 0;
        const headingTree: HeadingNode[] = [];
        let stopWriting = false;

        const parser = new Parser(
            {
                onopentag(name, attrs) {
                    name = name.toLowerCase();
                    if (name === "style") {
                        isInStyleTag = true;
                        styleHTML = `<style`;
                        if (attrs) {
                            for (const [key, value] of Object.entries(attrs)) {
                                styleHTML += ` ${key}="${value}"`;
                            }
                        }
                        styleHTML += `>`;
                        return;
                    }

                    if (name === "div" && attrs.role === "listitem") {
                        // Prefer a stable key if present; fall back to a monotonic index.
                        const cls = attrs.class || "";
                        const match = /item-([a-zA-Z0-9]{4,})/.exec(cls);
                        contentNodeKey = match?.[1] ?? String(contentNodeIndex++);

                        isInContentNode = true;
                        contentNode = "";
                        depth = 1;
                        return;
                    }

                    if (isInContentNode) {
                        depth++;
                        contentNode += `<${name}`;
                        if (attrs) {
                            for (const [key, value] of Object.entries(attrs)) {
                                contentNode += ` ${key}="${value}"`;
                            }
                        }
                        contentNode += `>`;
                    }
                },
                ontext(text) {
                    if (isInStyleTag) styleHTML += text;
                    else if (isInContentNode) contentNode += text;
                },
                onclosetag(name) {
                    name = name.toLowerCase();
                    if (name === "style" && isInStyleTag) {
                        styleHTML += `</style>`;
                        styles.push(styleHTML);
                        isInStyleTag = false;
                        styleHTML = "";
                        return;
                    }

                    if (!isInContentNode) return;

                    if (name === "div" && depth === 1) {
                        const cleaned = contentNode.trim();
                        if (!stopWriting && cleaned && contentNodeKey) {
                            const injected = injectHeadingIdsAndCollect(cleaned, contentNodeKey, headingTree, headingIndex, {
                                stopAtHeadingText: (headingText) =>
                                    headingText.includes("作业") && headingText.includes("Candy"),
                            });
                            headingIndex = injected.nextIndex;
                            if (injected.html) contentWriteStream.write(injected.html);
                            if (injected.stopped) stopWriting = true;
                        }
                        isInContentNode = false;
                        contentNodeKey = null;
                        contentNode = "";
                        depth = 0;
                        return;
                    }

                    depth--;
                    contentNode += `</${name}>`;
                },
                onend() {
                    resolve({ styleHTML: styles.join("\n"), headingTree });
                },
                onerror(err) {
                    reject(err);
                },
            },
            { decodeEntities: false }
        );

        readStream.on("data", (chunk) => {
            try {
                parser.write(typeof chunk === "string" ? chunk : chunk.toString("utf8"));
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
        readStream.on("error", reject);
    });
}

function printHelp() {
    console.log(`
Usage:
  tsx src/convert.ts [--dir <dir>] [--outDir <dir>]
  tsx src/convert.ts --file <input.html> [--out <output.html>] [--outDir <dir>]

Options:
  --file, -f     Convert a single HTML file
  --dir, -d      Convert all .html files in a directory (default: downloads)
  --outDir       Output directory (default: downloads2)
  --out, -o      Output file path (single-file mode only)
  --help, -h     Show help
`);
}

function parseArgs(argv: string[]): {
    mode: "dir" | "file";
    dir?: string;
    file?: string;
    outDir: string;
    outFile?: string;
    help: boolean;
} {
    const out: {
        mode: "dir" | "file";
        dir?: string;
        file?: string;
        outDir: string;
        outFile?: string;
        help: boolean;
    } = {
        mode: "dir",
        dir: "downloads",
        outDir: "downloads2",
        help: false,
    };

    const args = [...argv];
    const takeValue = (i: number, flag: string) => {
        const v = args[i + 1];
        if (!v || v.startsWith("-")) throw new Error(`Missing value for ${flag}`);
        return v;
    };

    for (let i = 0; i < args.length; i++) {
        const a = args[i];
        if (a === "--help" || a === "-h") {
            out.help = true;
            continue;
        }
        if (a === "--file" || a === "-f") {
            out.mode = "file";
            out.file = takeValue(i, a);
            i++;
            continue;
        }
        if (a === "--dir" || a === "-d") {
            out.mode = "dir";
            out.dir = takeValue(i, a);
            i++;
            continue;
        }
        if (a === "--outDir") {
            out.outDir = takeValue(i, a);
            i++;
            continue;
        }
        if (a === "--out" || a === "-o") {
            out.outFile = takeValue(i, a);
            i++;
            continue;
        }

        // Allow a positional file for convenience: `tsx src/convert.ts some.html`
        if (!a.startsWith("-") && (a.endsWith(".html") || a.endsWith(".htm"))) {
            out.mode = "file";
            out.file = a;
            continue;
        }
    }

    return out;
}

async function convertFile({
    filePath,
    outDir,
    outFile,
}: {
    filePath: string;
    outDir: string;
    outFile?: string;
}) {
    const title = path.basename(filePath).replace(/\.html?$/i, "");
    if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

    const safeBaseName = sanitizeFileName(title);
    const resolvedOutPath = outFile ? outFile : path.join(outDir, `${safeBaseName}.html`);

    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "doc-scraper-"));
    const tmpContentPath = path.join(tmpDir, `${safeBaseName}.content.html`);
    const contentWs = fs.createWriteStream(tmpContentPath, "utf8");

    const { styleHTML, headingTree } = await streamExtractAndWriteContent({
        file: filePath,
        contentWriteStream: contentWs,
    });

    await new Promise<void>((resolve, reject) => {
        contentWs.end(() => resolve());
        contentWs.on("error", reject);
    });

    const tocHTML = generateTOC(headingTree);
    const navigationHTML = generateNavigation(headingTree);

    const templatePath = path.resolve(getDir(import.meta.url), "assets/template.html");
    const template = fs.readFileSync(templatePath, "utf-8");
    const processedTemplate = template
        .replace("{{STYLES}}", styleHTML || "")
        .replace("{{TITLE}}", title)
        .replace("{{TOC}}", tocHTML)
        .replace("{{NAVIGATION}}", navigationHTML);

    const [headPart, tailPart] = processedTemplate.split("{{CONTENT}}");
    const outWs = fs.createWriteStream(resolvedOutPath, "utf8");
    outWs.write(headPart);

    await new Promise<void>((resolve, reject) => {
        const rs = fs.createReadStream(tmpContentPath, { encoding: "utf8" });
        rs.on("error", reject);
        outWs.on("error", reject);
        rs.on("end", () => resolve());
        rs.pipe(outWs, { end: false });
    });

    outWs.end(tailPart);

    // Best-effort cleanup
    try {
        fs.rmSync(tmpDir, { recursive: true, force: true });
    } catch { }

    return resolvedOutPath;
}


async function convert(dir: string, outDir: string) {
    const files = fs.readdirSync(dir);
    const htmlFiles = files.filter(file => file.endsWith(".html"));

    console.log(`Found ${htmlFiles.length} HTML files in directory: ${dir}`);

    for (const file of htmlFiles) {
        const filePath = path.join(dir, file);
        try {
            const outPath = await convertFile({ filePath, outDir });
            console.log(`Processed ${file}`);
            console.log(`  -> ${outPath}`);
        } catch (error) {
            console.error(`Error processing ${file}:`, error);
        }
    }
}

async function main() {
    let args;
    try {
        args = parseArgs(process.argv.slice(2));
    } catch (e) {
        console.error(String(e));
        printHelp();
        process.exitCode = 1;
        return;
    }

    if (args.help) {
        printHelp();
        return;
    }

    try {
        if (args.mode === "file") {
            if (!args.file) throw new Error("Missing --file <input.html>");
            const outPath = await convertFile({ filePath: args.file, outDir: args.outDir, outFile: args.outFile });
            console.log(`Done: ${outPath}`);
            return;
        }

        // Keep legacy defaults: directory mode uses `downloads` as input.
        await convert(args.dir ?? "downloads", args.outDir);
    } catch (e) {
        console.error(e);
        process.exitCode = 1;
    }
}

main();