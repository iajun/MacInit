const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

const PORT = 3000;
const BOOKS_DIR = path.join(__dirname, 'books');

// 确保书籍目录存在
if (!fs.existsSync(BOOKS_DIR)) {
  fs.mkdirSync(BOOKS_DIR, { recursive: true });
  console.log(`已创建书籍目录: ${BOOKS_DIR}`);
}

// 支持的电子书格式
const SUPPORTED_EXTENSIONS = ['.pdf', '.mobi', '.azw3', '.txt'];

// 生成简单的HTML页面
function generateHTML(bookFiles) {
  return `
<!DOCTYPE html>
<html>
<head>
  <title>Kindle书籍下载</title>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { 
      font-family: Arial, sans-serif; 
      margin: 0; 
      padding: 20px; 
      background: #f5f5f5;
      line-height: 1.4;
    }
    .container { 
      max-width: 800px; 
      margin: 0 auto; 
      background: white; 
      padding: 20px; 
      border-radius: 5px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }
    h1 { 
      color: #333; 
      text-align: center; 
      margin-top: 0;
    }
    .file-count {
      text-align: center;
      color: #666;
      margin-bottom: 20px;
    }
    .file-item { 
      padding: 12px; 
      border-bottom: 1px solid #eee; 
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .file-item:last-child {
      border-bottom: none;
    }
    .file-name {
      font-weight: bold;
      flex: 1;
      word-break: break-all;
    }
    .download-btn { 
      background: #4CAF50; 
      color: white; 
      padding: 6px 12px; 
      text-decoration: none; 
      border-radius: 3px;
      font-size: 14px;
      margin-left: 10px;
      white-space: nowrap;
    }
    .download-btn:hover {
      background: #45a049;
    }
    .empty { 
      text-align: center; 
      padding: 40px; 
      color: #666; 
      font-style: italic;
    }
    .refresh-btn { 
      background: #2196F3; 
      color: white; 
      padding: 10px 15px; 
      border: none; 
      border-radius: 3px;
      margin: 10px 0;
      cursor: pointer;
      display: block;
      width: 100%;
      font-size: 16px;
    }
    .file-size {
      color: #666;
      font-size: 12px;
      margin-left: 10px;
    }
    .instructions {
      background: #f9f9f9;
      padding: 15px;
      border-radius: 3px;
      margin-top: 20px;
      font-size: 14px;
      color: #666;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>📚 Kindle书籍下载</h1>
    <div class="file-count">找到 ${bookFiles.length} 本书籍</div>
    
    <button class="refresh-btn" onclick="location.reload()">🔄 刷新列表</button>
    
    <div class="file-list">
      ${bookFiles.length === 0 ? 
        '<div class="empty">暂无电子书文件<br>请将电子书放入books目录</div>' : 
        bookFiles.map(file => `
          <div class="file-item">
            <div class="file-name">${file.name}</div>
            <div>
              <span class="file-size">${file.size}</span>
              <a href="/download?file=${encodeURIComponent(file.name)}" class="download-btn">下载</a>
            </div>
          </div>
        `).join('')
      }
    </div>
    
    <div class="instructions">
      <strong>使用说明：</strong><br>
      1. 将电子书文件(.pdf, .mobi, .epub等)放入books目录<br>
      2. 点击"下载"按钮将书籍保存到Kindle<br>
      3. 下载完成后在Kindle图书馆中查看
    </div>
  </div>
</body>
</html>`;
}

// 格式化文件大小
function formatFileSize(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

// 获取文件列表
function getBookFiles() {
  try {
    const files = fs.readdirSync(BOOKS_DIR);
    return files
      .filter(file => SUPPORTED_EXTENSIONS.includes(path.extname(file).toLowerCase()))
      .map(file => {
        const filePath = path.join(BOOKS_DIR, file);
        const stats = fs.statSync(filePath);
        return {
          name: file,
          size: formatFileSize(stats.size)
        };
      });
  } catch (error) {
    console.error('读取文件列表错误:', error);
    return [];
  }
}

// 创建服务器
const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  
  // 设置CORS头部，确保跨域访问
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  // 处理预检请求
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }
  
  // 首页 - 显示文件列表
  if (pathname === '/' || pathname === '/index.html') {
    const bookFiles = getBookFiles();
    const html = generateHTML(bookFiles);
    
    res.writeHead(200, { 
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-cache'
    });
    res.end(html);
    return;
  }
  
  // 下载文件
  if (pathname === '/download') {
    const filename = parsedUrl.query.file;
    if (!filename) {
      res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('文件名不能为空');
      return;
    }
    
    // 解码并安全检查
    const decodedFilename = decodeURIComponent(filename);
    const filePath = path.join(BOOKS_DIR, decodedFilename);
    
    // 防止目录遍历攻击
    if (!filePath.startsWith(BOOKS_DIR) || decodedFilename.includes('..')) {
      res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('访问被拒绝');
      return;
    }
    
    // 检查文件是否存在
    if (!fs.existsSync(filePath)) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('文件不存在: ' + decodedFilename);
      return;
    }
    
    // 检查文件格式是否支持
    const ext = path.extname(decodedFilename).toLowerCase();
    if (!SUPPORTED_EXTENSIONS.includes(ext)) {
      res.writeHead(400, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('不支持的文件格式: ' + ext);
      return;
    }
    
    try {
      const stats = fs.statSync(filePath);
      const fileStream = fs.createReadStream(filePath);
      
      // 设置下载头部
      res.writeHead(200, {
        'Content-Type': 'application/octet-stream',
        'Content-Length': stats.size,
        'Cache-Control': 'no-cache'
      });
      
      fileStream.pipe(res);
      console.log(`开始下载: ${decodedFilename} (${formatFileSize(stats.size)})`);
      
    } catch (error) {
      console.error('下载错误:', error);
      res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('下载失败: ' + error.message);
    }
    return;
  }
  
  // 其他路径返回404
  res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`
    <html>
      <body>
        <h1>页面未找到</h1>
        <p><a href="/">返回首页</a></p>
      </body>
    </html>
  `);
});

// 启动服务器
server.listen(PORT, '0.0.0.0', () => {
  const os = require('os');
  const networkInterfaces = os.networkInterfaces();
  
  console.log('🎯 Kindle书籍下载服务器已启动!');
  console.log('================================');
  console.log(`📚 服务器端口: ${PORT}`);
  console.log(`📁 书籍目录: ${BOOKS_DIR}`);
  console.log('');
  console.log('🌐 可用访问地址:');
  
  // 显示所有网络接口的IP
  let hasExternalIP = false;
  Object.keys(networkInterfaces).forEach(interfaceName => {
    networkInterfaces[interfaceName].forEach(interface => {
      if (interface.family === 'IPv4' && !interface.internal) {
        console.log(`    http://${interface.address}:${PORT}`);
        hasExternalIP = true;
      }
    });
  });
  
  if (!hasExternalIP) {
    console.log('    (未检测到网络连接，请检查WiFi设置)');
  }
  
  console.log('');
  console.log('📖 在Kindle浏览器中访问上述地址');
  console.log('💡 确保Kindle和电脑在同一WiFi网络下');
  console.log('================================');
  
  // 显示当前目录中的书籍文件
  const bookFiles = getBookFiles();
  if (bookFiles.length > 0) {
    console.log('\n📚 当前可下载的书籍:');
    bookFiles.forEach(file => {
      console.log(`    • ${file.name} (${file.size})`);
    });
  } else {
    console.log('\n💡 请将电子书文件放入books目录');
  }
});

// 优雅关闭
process.on('SIGINT', () => {
  console.log('\n👋 服务器已关闭');
  process.exit(0);
});