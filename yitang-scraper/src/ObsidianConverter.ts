import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';
import { createReadStream, createWriteStream } from 'fs';
import { Parser } from 'htmlparser2';

// 存储每个文本片段的样式
interface TextSegment {
  text: string;
  styles: {
    bold: boolean;
    italic: boolean;
    underline: boolean;
    highlight: boolean;
    highlightColor?: string;
  };
}

type BlockType =
  | 'heading'
  | 'ordered'
  | 'unordered'
  | 'quote'
  | 'text';

class ObsidianConverter {
  private outputDir: string;
  private imageDir: string;
  private imageCounter = 1;
  private fileShortHash: string;
  private sourceFileName: string;
  private mdStream: fs.WriteStream;

  // 新增：控制是否停止写入的标志
  private stopWriting = false;
  // 新增：记录当前是否在引用块内
  private inQuoteBlock = false;

  // 解析状态
  private parser: Parser;
  private currentBlock: any = null;
  private blockDepth = 0;
  private currentSegments: TextSegment[] = []; // 存储带样式的文本片段
  private currentSpanStyles: any = {
    bold: false,
    italic: false,
    underline: false,
    highlight: false,
    highlightColor: ''
  };

  // 格式状态
  private lastBlockType: BlockType | null = null;
  private orderedCounter = 1;
  /** 是否已向 md 写入过实质内容（用于检测「有 listitem 但深度错位 / 无块」等异常） */
  private anyContentWritten = false;

  constructor(
    private filePath: string,
    outputDir: string = './obsidian-output'
  ) {
    this.sourceFileName = path.basename(filePath).replace(/\.[^/.]+$/, '');
    this.outputDir = outputDir;
    this.fileShortHash = this.generateShortHash(this.sourceFileName);
    this.imageDir = path.join(outputDir, 'assets/images', this.sourceFileName);

    this.createDir(this.outputDir);
    this.createDir(this.imageDir);

    const mdFile = path.join(outputDir, `${this.sourceFileName}.md`);
    this.mdStream = createWriteStream(mdFile, 'utf8');

    this.initParser();
  }

  private generateShortHash(s: string): string {
    return crypto.createHash('md5').update(s).digest('hex').slice(0, 8);
  }

  private createDir(p: string) {
    if (!fs.existsSync(p)) fs.mkdirSync(p, { recursive: true });
  }

  // 提取标题级别
  private getHeadingLevel(cls: string): number {
    const m = cls?.match(/docx-heading(\d+)-block/);
    if (!m) return 0;
    const lv = parseInt(m[1]);
    return Math.max(1, Math.min(6, lv));
  }

  // 清理文本中的原生列表符号
  private cleanListSymbols(text: string): string {
    if (!text) return '';
    text = text.replace(/^\s*[•·*\-]\s+/, '');
    text = text.replace(/^\s*\d+\.\s+/, '');
    text = text.replace(/\s+/g, ' ').trim();
    return text;
  }

  // 解析span样式类
  private parseSpanStyles(classStr: string): void {
    this.currentSpanStyles = {
      bold: classStr.includes('bold'),
      italic: classStr.includes('italic'),
      underline: classStr.includes('underline'),
      highlight: classStr.includes('textHighlight'),
      highlightColor: classStr.match(/textHighlight-(\w+)-text/)?.[1] || ''
    };
  }

  // 应用样式到文本片段
  private applyStyles(segment: TextSegment): string {
    let text = segment.text;
    if (!text) return '';

    // 按优先级应用样式：斜体 → 下划线 → 加粗 → 高亮
    if (segment.styles.italic) text = `*${text}*`;
    if (segment.styles.underline) text = `__${text}__`;
    if (segment.styles.bold) text = `**${text}**`;
    if (segment.styles.highlight) text = `==${text}==`;

    return text;
  }

  private initParser() {
    this.parser = new Parser(
      {
        onopentag: (name, attrs) => {
          // 如果已经触发停止写入，直接返回
          if (this.stopWriting) return;

          const role =
            typeof attrs.role === 'string' ? attrs.role.toLowerCase() : '';

          // 开始新的 listitem 块（与 convert.ts 一致：本标签不计入 blockDepth，避免永远达不到 0）
          if (name === 'div' && role === 'listitem') {
            this.currentBlock = {
              textSegments: [] as TextSegment[],
              images: [] as string[],
              headingLevel: 0,
              isQuote: false,
              isOrdered: false,
              isUnordered: false
            };
            this.blockDepth = 1;
            this.currentSegments = [];
            this.currentSpanStyles = {
              bold: false,
              italic: false,
              underline: false,
              highlight: false,
              highlightColor: ''
            };
            return;
          }

          if (this.currentBlock) {
            this.blockDepth++;
            const cls = attrs.class || '';

            // 解析块级属性
            if (name === 'div') {
              // 标题
              const hlv = this.getHeadingLevel(cls);
              if (hlv) this.currentBlock.headingLevel = hlv;
              // 引用
              if (cls.includes('docx-quote_container-block')) {
                this.currentBlock.isQuote = true;
                this.inQuoteBlock = true; // 标记进入引用块
              }
              // 列表类型（支持引用内列表）
              if (cls.includes('docx-ordered-block')) {
                this.currentBlock.isOrdered = true;
              }
              if (cls.includes('docx-bullet-block')) {
                this.currentBlock.isUnordered = true;
              }
            }

            // 解析span样式（核心：实时更新当前样式）
            if (name === 'span') {
              this.parseSpanStyles(cls);
            }

            // 收集图片
            if (name === 'img' && attrs.src) {
              this.currentBlock.images.push(attrs.src);
            }
          }
        },

        ontext: (text) => {
          // 如果已经触发停止写入，直接返回
          if (this.stopWriting || !this.currentBlock || !text.trim()) return;
          
          // 清理文本并创建带样式的片段
          const cleanText = text.replace(/\u200B|\s+/g, ' ').trim();
          if (cleanText) {
            // 检查是否是"作业与Candy"标题文本
            if (this.currentBlock.headingLevel > 0 && cleanText.includes('作业') && cleanText.includes('Candy')) {
              this.stopWriting = true; // 触发停止写入标志
              return;
            }
            this.currentSegments.push({
              text: cleanText,
              styles: { ...this.currentSpanStyles } // 复制当前样式
            });
          }
        },

        onclosetag: (name) => {
          // 如果已经触发停止写入，直接返回
          if (this.stopWriting) return;

          if (!this.currentBlock) return;
          this.blockDepth--;

          // span结束：重置样式
          if (name === 'span') {
            this.currentSpanStyles = {
              bold: false,
              italic: false,
              underline: false,
              highlight: false,
              highlightColor: ''
            };
          }

          // 引用块结束，重置标记
          if (name === 'div' && this.inQuoteBlock && this.blockDepth <= 1) {
            this.inQuoteBlock = false;
          }

          // listitem块结束：合并所有文本片段
          if (this.blockDepth === 0) {
            // 合并当前片段到块
            this.currentBlock.textSegments = [...this.currentSegments];
            this.writeBlock(this.currentBlock);
            this.currentBlock = null;
            this.currentSegments = [];
          }
        },

        onend: () => {
          if (!this.anyContentWritten && !this.stopWriting) {
            this.appendFallbackPlainText();
          }
          this.mdStream.end(() => {
            console.log(`✅ ${this.sourceFileName}.md`);
          });
        },
        onerror: (err) => {
          console.error('解析错误', err);
        }
      },
      { decodeEntities: true }
    );
  }

  // 图片处理
  private saveImage(src: string): string {
    const m = src.match(/^data:(image\/\w+);base64,(.+)/);
    if (!m) return '';
    const ext = m[1].split('/')[1] || 'png';
    const name = `${this.fileShortHash}-${this.imageCounter++}.${ext}`;
    const dest = path.join(this.imageDir, name);
    fs.writeFileSync(dest, Buffer.from(m[2], 'base64'));
    return `![[${this.sourceFileName}/${name}]]`;
  }

  // 判断块类型
  private getBlockType(b: any): BlockType {
    if (b.headingLevel) return 'heading';
    if (b.isQuote) return 'quote';
    if (b.isOrdered) return 'ordered';
    if (b.isUnordered) return 'unordered';
    return 'text';
  }

  // 核心写入逻辑
  private writeBlock(b: any) {
    // 如果已经触发停止写入，直接返回
    if (this.stopWriting) return;

    // 1. 处理所有带样式的文本片段
    let textParts: string[] = [];
    b.textSegments.forEach((segment: TextSegment) => {
      const styledText = this.applyStyles(segment);
      if (styledText) textParts.push(styledText);
    });
    let fullText = textParts.join(' ');
    
    // 2. 清理列表符号
    fullText = this.cleanListSymbols(fullText);
    if (!fullText && !b.images.length) return;

    // 3. 处理图片（重点修改：引用内图片前后加空行）
    const imgs = b.images.map((s: string) => this.saveImage(s)).filter(Boolean);
    let finalContent = '';
    
    if (b.isQuote) {
      // 引用块内的内容处理
      let parts = [fullText];
      // 插入图片并在前后加空行
      imgs.forEach(img => {
        parts = parts.flatMap(part => [part, '', img, '']);
      });
      // 过滤空字符串并拼接
      finalContent = parts.filter(Boolean).join('\n> ').trim();
    } else {
      // 非引用块正常处理
      finalContent = [...imgs, fullText].filter(Boolean).join(' ').trim();
    }

    if (!finalContent) return;

    const now = this.getBlockType(b);

    // 4. 空行规则（优化：支持引用内列表的空行规则）
    const isSameList =
      (now === 'ordered' && this.lastBlockType === 'ordered') ||
      (now === 'unordered' && this.lastBlockType === 'unordered');

    // 引用内的列表不添加额外空行
    const isQuoteList = b.isQuote && (now === 'ordered' || now === 'unordered');
    if (this.lastBlockType && !isSameList && !isQuoteList) {
      this.mdStream.write('\n\n');
    }

    // 5. 构造输出行
    let out = '';
    if (now === 'heading') {
      out = `${'#'.repeat(b.headingLevel)} ${finalContent}`;
    } else if (now === 'quote') {
      // 引用块处理：每行都加 > 前缀
      const lines = finalContent.split('\n');
      out = lines.map(line => line ? `> ${line}` : '>').join('\n');
    } else if (now === 'ordered') {
      if (this.lastBlockType !== 'ordered') this.orderedCounter = 1;
      out = `${this.orderedCounter++}. ${finalContent}`;
    } else if (now === 'unordered') {
      out = `- ${finalContent}`;
    } else {
      out = finalContent;
    }

    this.mdStream.write(out + '\n');
    this.lastBlockType = now;
    this.anyContentWritten = true;
  }

  /** 无 listitem 块或解析未写出任何行时，尽力从 HTML 抽出可见文本，避免生成空文件 */
  private appendFallbackPlainText(): void {
    let raw: string;
    try {
      raw = fs.readFileSync(this.filePath, 'utf8');
    } catch {
      return;
    }
    const stripped = raw
      .replace(/<script[\s\S]*?<\/script>/gi, '')
      .replace(/<style[\s\S]*?<\/style>/gi, '')
      .replace(/<[^>]+>/g, '\n')
      .replace(/&nbsp;/g, ' ')
      .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(parseInt(n, 10)))
      .replace(/&#x([0-9a-fA-F]+);/g, (_, h) => String.fromCharCode(parseInt(h, 16)))
      .replace(/\n{3,}/g, '\n\n')
      .trim();
    if (!stripped) return;
    this.mdStream.write(
      '<!-- doc-scraper: 未识别到 Feishu listitem 块，以下为纯文本回退 -->\n\n'
    );
    this.mdStream.write(stripped + '\n');
    this.anyContentWritten = true;
  }

  async convert() {
    return new Promise<void>((resolve, reject) => {
      const rs = createReadStream(this.filePath, {
        encoding: 'utf8',
        highWaterMark: 2 * 1024 * 1024
      });
      rs.on('data', (c) => this.parser.write(c));
      rs.on('end', () => {
        this.parser.end();
        resolve();
      });
      rs.on('error', reject);
    });
  }
}

/** 递归收集目录下所有 .html，保留相对 inputRoot 的子路径用于输出镜像 */
function collectHtmlFiles(
  dir: string,
  inputRoot: string,
  acc: { fullPath: string; outputSubdir: string }[] = []
): { fullPath: string; outputSubdir: string }[] {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      collectHtmlFiles(full, inputRoot, acc);
    } else if (ent.isFile() && ent.name.endsWith('.html')) {
      const relDir = path.relative(inputRoot, dir);
      const outputSubdir =
        !relDir || relDir === '.' ? '' : relDir;
      acc.push({ fullPath: full, outputSubdir });
    }
  }
  return acc;
}

// 批量转换（含子目录，输出目录结构与输入一致）
async function batch(input: string, output = '/Users/sharpzhou/Desktop/lesson-vault') {
  const inputRoot = path.resolve(input);
  const outRoot = path.resolve(output);
  const files = collectHtmlFiles(inputRoot, inputRoot);
  console.log(`📁 共 ${files.length} 个文件（含子目录）`);

  for (const { fullPath, outputSubdir } of files) {
    try {
      const rel = path.relative(inputRoot, fullPath);
      console.log('处理：', rel || path.basename(fullPath));
      const outDir = outputSubdir ? path.join(outRoot, outputSubdir) : outRoot;
      const c = new ObsidianConverter(fullPath, outDir);
      await c.convert();
    } catch (e) {
      console.error('❌ 失败：', fullPath, (e as Error).message);
    }
  }
  console.log('\n🎉 全部完成');
}

// 运行（替换为你的HTML文件目录）
batch('/Users/sharpzhou/Desktop/lesson');