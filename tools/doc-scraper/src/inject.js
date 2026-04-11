// ==============================================
// 第一步：全局拦截，捕获所有生成的 Blob 和对应 URL（核心！）
// 必须在 blob:URL 生成之前运行（页面加载时运行最佳）
// ==============================================
window.blobCache = new Map(); // 缓存：key=blobURL, value=原始Blob对象
const originalCreateObjectURL = URL.createObjectURL;
const originalRevokeObjectURL = URL.revokeObjectURL;

// 重写创建方法，自动缓存Blob
URL.createObjectURL = function(blob) {
  const blobURL = originalCreateObjectURL.call(URL, blob);
  window.blobCache.set(blobURL, blob); // 永久缓存原始Blob
  return blobURL;
};

// 重写销毁方法，清理缓存（可选，不影响功能）
URL.revokeObjectURL = function(blobURL) {
  window.blobCache.delete(blobURL);
  originalRevokeObjectURL.call(URL, blobURL);
};

// ==============================================
// 第二步：优化后的 Base64 转换函数（稳定无失效）
// ==============================================
async function convertToBase64(url) {
  // 跳过已处理的 data:URL
  if (url.startsWith("data:")) return url;

  try {
    // ==============================================
    // 核心优化：直接从缓存拿原始Blob，不使用fetch！
    // ==============================================
    if (url.startsWith("blob:")) {
      // 1. 优先从全局缓存获取原始Blob（100%有效）
      const cachedBlob = window.blobCache.get(url);
      if (cachedBlob) {
        return await blobToBase64(cachedBlob);
      }

      // 2. 兜底：缓存未命中（仅兼容已生成的旧blobURL），增强版fetch
      return await fetchBlobToBase64(url);
    }

    // ==============================================
    // 普通URL逻辑（原逻辑优化，更简洁）
    // ==============================================
    const response = await fetch(url, { mode: "cors" });
    const blob = await response.blob();
    return await blobToBase64(blob);

  } catch (error) {
    console.warn("[图片转换失败]", url, error);
    return url;
  }
}

// 工具函数：Blob 转 Base64
function blobToBase64(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}

// 兜底工具函数：增强版fetch blobURL（带重试+超时）
async function fetchBlobToBase64(blobURL, retries = 2) {
  while (retries-- > 0) {
    try {
      const res = await fetch(blobURL, { signal: AbortSignal.timeout(3000) });
      const blob = await res.blob();
      return await blobToBase64(blob);
    } catch (e) {
      if (retries === 0) throw e;
      await new Promise(r => setTimeout(r, 500)); // 重试间隔
    }
  }
}

// 挂载到全局
window.convertToBase64 = convertToBase64;