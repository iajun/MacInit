// insert-html-snippets.js
const fs = require("fs");
const path = require("path");
const cheerio = require("cheerio");
const prettier = require("prettier");
const { glob } = require("glob");

// ======== 配置 ========
const sourceDir =
  "/Users/sharpzhou/Downloads/YiTang" ||
  path.resolve(__dirname, "your-html-folder"); // 原始HTML目录
const outputDir =
  "/Users/sharpzhou/Downloads/YiTang2" ||
  path.resolve(__dirname, "output-html"); // 新的输出目录
// =====================

// head 插入内容
const headInsert = `
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<style>
/* 对话框样式 */
#imageViewer {
  display: none;
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.85);
  z-index: 9999;
  align-items: center;
  justify-content: center;
  flex-direction: column;
}
#imageViewer img {
  max-width: 90%;
  max-height: 80%;
  transition: transform 0.3s;
}
#imageViewer .controls {
  color: white;
  font-size: 18px;
  margin-top: 10px;
}
#imageViewer button {
  margin: 0 5px;
  background: rgba(255,255,255,0.2);
  border: none;
  padding: 6px 12px;
  color: white;
  cursor: pointer;
  border-radius: 4px;
}
#imageViewer button:hover {
  background: rgba(255,255,255,0.4);
}
</style>

<style type="text/css">
  .content-container {
    max-width: 800px;     /* PC 端最大宽度 */
    margin: 0 auto;       /* 居中显示 */
    padding: 0 16px;      /* 两侧留空，移动端防贴边 */
    box-sizing: border-box;
  }
  
  /* 可选：更窄屏幕下额外优化 */
  @media (max-width: 820px) {
    .content-container {
      max-width: 100%;    /* 移动端全宽 */
      padding: 0 12px;    /* 两侧稍微小一点间距 */
    }
  }
</style>
`;

// body 插入内容
const bodyInsert = `
<div id="imageViewer">
  <div id="viewerWrapper">
    <img id="viewerImage" src="" alt="">
    <div class="controls">
      <button id="prevBtn">⟨</button>
      <span id="imageCounter">0/0</span>
      <button id="nextBtn">⟩</button>
      <button id="zoomInBtn">+</button>
      <button id="zoomOutBtn">-</button>
      <button id="closeBtn">✕</button>
    </div>
  </div>
</div>

<script>
(function() {
  const images = document.querySelectorAll('.img');
  const viewer = document.getElementById('imageViewer');
  const viewerImage = document.getElementById('viewerImage');
  const counter = document.getElementById('imageCounter');
  let currentIndex = 0;
  let scale = 1;

  function showImage(index) {
    currentIndex = index;
    viewerImage.src = images[currentIndex].src.replace('/300/200', '/1200/800');
    scale = 1;
    viewerImage.style.transform = \`scale(\${scale})\`;
    counter.textContent = \`\${currentIndex + 1}/\${images.length}\`;
    viewer.style.display = 'flex';
  }

  images.forEach((img, idx) => {
    img.style.cursor = 'pointer';
    img.addEventListener('click', () => showImage(idx));
  });

  document.getElementById('prevBtn').onclick = () => {
    showImage((currentIndex - 1 + images.length) % images.length);
  };
  document.getElementById('nextBtn').onclick = () => {
    showImage((currentIndex + 1) % images.length);
  };
  document.getElementById('zoomInBtn').onclick = () => {
    scale += 0.2;
    viewerImage.style.transform = \`scale(\${scale})\`;
  };
  document.getElementById('zoomOutBtn').onclick = () => {
    scale = Math.max(0.2, scale - 0.2);
    viewerImage.style.transform = \`scale(\${scale})\`;
  };
  document.getElementById('closeBtn').onclick = () => {
    viewer.style.display = 'none';
  };

  // 滚轮缩放
  viewerImage.addEventListener('wheel', e => {
    e.preventDefault();
    scale += e.deltaY < 0 ? 0.1 : -0.1;
    scale = Math.max(0.2, scale);
    viewerImage.style.transform = \`scale(\${scale})\`;
  });

  // 移动端双指缩放
  let lastDist = 0;
  viewerImage.addEventListener('touchmove', e => {
    if (e.touches.length === 2) {
      e.preventDefault();
      const dx = e.touches[0].clientX - e.touches[1].clientX;
      const dy = e.touches[0].clientY - e.touches[1].clientY;
      const dist = Math.sqrt(dx*dx + dy*dy);
      if (lastDist) {
        const diff = dist - lastDist;
        scale += diff / 200;
        scale = Math.max(0.2, scale);
        viewerImage.style.transform = \`scale(\${scale})\`;
      }
      lastDist = dist;
    }
  }, { passive: false });
  viewerImage.addEventListener('touchend', () => lastDist = 0);
})();
</script>
`;

async function main() {
  // 扫描HTML文件
  const files = await glob(`${sourceDir}/**/*.html`);
  console.log(files);

  files.forEach((file) => {
    let html = fs.readFileSync(file, "utf8");
    const $ = cheerio.load(html, { decodeEntities: false });

    // ===== 功能1：head 插入 =====
    $("head").append(headInsert);

    // ===== 功能2：body 插入 =====
    $("body").append(bodyInsert);

    // ===== 功能3：第一个 div 改 class =====
    const firstDiv = $("body > div").first();
    if (firstDiv.length) {
      firstDiv.removeAttr("style");
      firstDiv.addClass("content-container");
    }

    // ===== 功能4：prettier 格式化 =====
    const formatted = prettier.format($.html(), { parser: "html" });

    // 计算输出路径
    const relativePath = path.relative(sourceDir, file);
    const outputPath = path.join(outputDir, relativePath);

    // 创建目录
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });

    // 写入新文件
    fs.writeFileSync(outputPath, formatted, "utf8");
    console.log(`✅ 已生成: ${outputPath}`);
  });

  console.log("🎉 所有 HTML 文件已处理完成（已输出到新目录）！");
}

main();
