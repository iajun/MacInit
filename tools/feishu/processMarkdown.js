const fs = require("fs");
const os = require("os");
const path = require("path");

// Function to get all file names in the Downloads directory with the given prefix
function getFileName(prefix, mediaPath) {
  const files = fs.readdirSync(mediaPath);
  const matchedFile = files.find((file) => file.startsWith(prefix));
  return matchedFile ? matchedFile : null;
}

function escapeRegExp(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); // Escapes special characters for regular expression
}

// Function to replace links in the markdown
function replaceLinks(markdown, jsonMap, mediaPath) {
  for (const [link, prefix] of Object.entries(jsonMap)) {
    const fileName = getFileName(prefix, mediaPath);
    console.log(fileName);
    if (fileName) {
      const escapedLink = escapeRegExp(link);
      markdown = markdown.replace(
        new RegExp(`!\\[\\]\\(${escapedLink}\\)`, "g"),
        `![[${fileName}]]`,
      );
    }
  }
  return markdown;
}

// Main function to process the markdown file
async function processMarkdown(markdownFilePath, jsonMapPath, mediaPath) {
  try {
    const jsonMap = JSON.parse(fs.readFileSync(jsonMapPath, "utf8"));
    let markdown = fs.readFileSync(markdownFilePath, "utf8");

    // Replace links
    markdown = replaceLinks(markdown, jsonMap, mediaPath);

    // Remove multiple blank lines
    markdown = markdown.replace(/\n{2,}/g, "\n\n");

    markdown = markdown.replace(/Unable to print\n/g, "");

    // Remove lines with only a percentage value
    markdown = markdown.replace(/^\d+%$\n/gm, "");

    // Write processed content to a new markdown file
    fs.writeFileSync("processedMarkdown.md", markdown);
    console.log("Markdown processed successfully");
  } catch (error) {
    console.error("Error processing markdown:", error);
  }
}

// Example usage
const basePath =
  "/Users/sharpzhou/Library/Mobile Documents/iCloud~md~obsidian/Documents/notebook";
const markdownFilePath = `${basePath}/_Sources/🎯直播 Live 第 138 场：开源之夜 · 知识管理专场 - Feishu Docs.md`;
const jsonMapPath = path.join(__dirname, "./map.json");
// const downloadsPath = path.join(os.homedir(), "Downloads");
const mediaPath = path.join(basePath, "_Media");

processMarkdown(markdownFilePath, jsonMapPath, mediaPath);

