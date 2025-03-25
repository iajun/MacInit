async function convertToBase64(url) {
    // 跳过已处理的图片
    if (url.startsWith("data:")) return url;

    try {
        let response;
        // 区分 Blob 和普通请求
        if (url.startsWith("blob:")) {
            response = await fetch(url);
            const blob = await response.blob();
            return await new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = () => resolve(reader.result);
                reader.onerror = reject;
                reader.readAsDataURL(blob);
            });
        } else {
            // 普通图片使用 arrayBuffer 避免 401
            response = await fetch(url, {
                // credentials: "include", // 携带 cookie
                mode: "cors", // 强制 CORS 模式
            });
            const buffer = await response.arrayBuffer();
            const type = response.headers.get("Content-Type") || "image/png";
            const base64 = btoa(
                new Uint8Array(buffer).reduce(
                    (data, byte) => data + String.fromCharCode(byte),
                    "",
                ),
            );
            return `data:${type};base64,${base64}`;
        }
    } catch (error) {
        console.warn("[图片转换失败]", url, error);
        return url; // 失败时保留原 URL
    }
}

window.convertToBase64 = convertToBase64;