import fs from "fs";
import { Readable } from "stream";
import { load } from "cheerio";

interface HeadingNode {
    id: string;
    text: string;
    level: number;
    children: HeadingNode[];
}

const initDownloadDir = (downloadDir: string) => {
    if (!fs.existsSync(downloadDir)) {
        fs.mkdirSync(downloadDir);
    }
}


const insertHeadingIntoTree = (heading: HeadingNode, headingTree: HeadingNode[]) => {
    if (headingTree.length === 0) {
        headingTree.push(heading);
        return;
    }

    // 找到合适的父级标题
    let currentLevel = 0;
    let currentPath: HeadingNode[] = [headingTree[0]];

    for (let i = 1; i < headingTree.length; i++) {
        const node = headingTree[i];

        if (node.level < heading.level) {
            // 当前节点级别更低，可以作为父级
            currentLevel = node.level;
            currentPath = headingTree.slice(0, i + 1);
        } else if (node.level === heading.level) {
            // 同级标题，添加到同级
            currentPath = headingTree.slice(0, i);
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
        headingTree.push(heading);
    }
}

const generateNavigation = (headingTree: HeadingNode[]): string => {
    if (headingTree.length === 0) {
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
          ${generateNavItems(headingTree)}
        </ul>
      </nav>
    `;
}

const extractHeadings = (contentNodes: Map<string, string>) => {
    const headingTree: HeadingNode[] = [];

    for (const [nodeId, html] of contentNodes) {
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
                    insertHeadingIntoTree(headingNode, headingTree);
                }
            }
        });

        // 更新HTML内容
        contentNodes.set(nodeId, $.html());
    }

    return {
        headingTree,
        contentNodes
    };
}

const generateTOC = (headingTree: HeadingNode[]): string => {
    if (headingTree.length === 0) {
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
          ${generateTOCItems(headingTree)}
        </div>
      </div>
    `;
}

export async function htmlGenerator({
    contentNodes,
    title,
    styleHTML,
    downloadDir
}: {
    contentNodes: Map<string, string>;
    title: string;
    styleHTML: string;
    downloadDir: string;
}) {
    styleHTML = '';
    initDownloadDir(downloadDir);

    const filePath = `${downloadDir}/${title}.html`;
    const writeStream = fs.createWriteStream(filePath);
    let headingTree: HeadingNode[] = [];

    ({ headingTree, contentNodes } = extractHeadings(contentNodes));

    // 生成TOC和导航
    const tocHTML = generateTOC(headingTree);
    const navigationHTML = generateNavigation(headingTree);


    // 读取模板文件
    const templatePath = "./src/assets/template.html";
    const template = fs.readFileSync(templatePath, "utf-8");


    // 替换模板中的占位符
    const processedTemplate = template
        .replace("{{STYLES}}", styleHTML)
        .replace("{{TITLE}}", title)
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
            for (const [nodeId, html] of contentNodes) {
                this.push(html);
            }
            this.push(null);
        }
    });

    // 设置 contentNodes 到流中
    (contentStream as any).contentNodes = contentNodes;

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