import fs from "fs";
import path from "path";
import { Parser } from "htmlparser2";
import { htmlGenerator } from "./HTMLGenerator";

const getTitleAndContentNodes = async (file: string) => {
    return new Promise<{ contentNodes: Map<string, string>, styleHTML: string }>((resolve, reject) => {
        const readStream = fs.createReadStream(file, { encoding: 'utf8' });
        const contentNodes = new Map<string, string>();
        const styles: string[] = [];
        let contentNodeId: string | null = null;
        let contentNode = '';
        let isInContentNode = false;
        let depth = 0; // 跟踪嵌套深度
        let styleHTML = '';
        let isInStyleTag = false;

        // <div role="listitem" class=" clearfix item-0 item-OHQUdgEr1okiLAxJs4wcMzYjnhb listitem">
        const parser = new Parser(
            {
                onopentag(name, attrs) {
                    name = name.toLowerCase();

                    if (name === 'style') {
                        // 开始收集 style 标签内容
                        isInStyleTag = true;
                        styleHTML = `<style`;
                        if (attrs) {
                            Object.entries(attrs).forEach(([key, value]) => {
                                styleHTML += ` ${key}="${value}"`;
                            });
                        }
                        styleHTML += '>';
                    } else if (name === 'div' && attrs.role === 'listitem' && attrs.class?.includes('item-')) {
                        // 提取 item- 后面的 ID，使用捕获组只取 ID 部分
                        const match = /item-([a-zA-Z0-9]{4,})/.exec(attrs.class);
                        if (match) {
                            contentNodeId = match[1]; // 只取 ID 部分，不包含 "item-" 前缀
                            isInContentNode = true;
                            contentNode = '';
                            depth = 1;
                        }
                    } else if (isInContentNode) {
                        // 如果已经在内容节点内，增加深度计数并保留标签结构
                        depth++;
                        contentNode += `<${name}`;
                        if (attrs) {
                            Object.entries(attrs).forEach(([key, value]) => {
                                contentNode += ` ${key}="${value}"`;
                            });
                        }
                        contentNode += '>';
                    }
                },
                ontext(text) {
                    if (isInStyleTag) {
                        styleHTML += text;
                    } else if (isInContentNode && contentNodeId) {
                        contentNode += text;
                    }
                },
                onclosetag(name) {
                    if (name === 'style' && isInStyleTag) {
                        // 完成 style 标签收集
                        styleHTML += '</style>';
                        styles.push(styleHTML);
                        isInStyleTag = false;
                        styleHTML = '';
                    } else if (isInContentNode && contentNodeId) {
                        if (name === 'div' && depth === 1) {
                            // 到达最外层的 div 结束标签
                            const cleanedContent = contentNode.trim();
                            if (cleanedContent) {
                                contentNodes.set(contentNodeId, cleanedContent);
                            }
                            isInContentNode = false;
                            contentNodeId = null;
                            contentNode = '';
                            depth = 0;
                        } else if (isInContentNode) {
                            // 其他标签的结束标签
                            depth--;
                            contentNode += `</${name}>`;
                        }
                    }
                },
                onend() {
                    resolve({ contentNodes, styleHTML: styles.join('\n') });
                },
                onerror(err) {
                    reject(err);
                },
            },
            { decodeEntities: false } // 保持原始实体表现
        );

        readStream.on('data', (chunk) => {
            try {
                parser.write(chunk.toString());
            } catch (err) {
                reject(err);
            }
        });

        readStream.on('end', () => {
            try {
                parser.end();
            } catch (err) {
                reject(err);
            }
        });

        readStream.on('error', (err) => reject(err));
    });
}


async function convert(dir: string) {
    const files = fs.readdirSync(dir);
    const htmlFiles = files.filter(file => file.endsWith(".html"));

    console.log(`Found ${htmlFiles.length} HTML files in directory: ${dir}`);

    for (const file of htmlFiles) {
        const filePath = path.join(dir, file);
        try {
            const { contentNodes, styleHTML } = await getTitleAndContentNodes(filePath);
            await htmlGenerator({ contentNodes, styleHTML, title: file.replace('.html', ''), downloadDir: 'downloads2' });
            console.log(`Processed ${file}`);
        } catch (error) {
            console.error(`Error processing ${file}:`, error);
        }
    }
}

convert('downloads');