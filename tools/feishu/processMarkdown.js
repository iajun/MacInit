const fs = require("fs");
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
function replaceLinks(markdown, mediaPath) {
  for (const fileName of fs.readdirSync(mediaPath, "utf-8")) {
    if (fileName) {
      const escapedLink = escapeRegExp(fileName.split(".")[0]);
      console.log(fileName, escapedLink)
      markdown = markdown.replace(
        new RegExp(`!\\[\\]\\(.*?${escapedLink}\\)`, "g"),
        `![[${fileName}]]`,
      );
    }
  }
  return markdown;
}

// Main function to process the markdown file
async function processMarkdown(markdownFilePath, mediaPath) {
  try {
    let markdown = fs.readFileSync(markdownFilePath, "utf8");

    // Replace links
    markdown = replaceLinks(markdown, mediaPath);

    // Remove multiple blank lines
    markdown = markdown.replace(/\n{2,}/g, "\n\n");

    [/\u200B/g, /Unable to print\n/g, /附件不支持打印/g].forEach(
      (m) => (markdown = markdown.replace(m, "")),
    );

    // Remove lines with only a percentage value
    markdown = markdown.replace(/^\d+%$\n/gm, "");

    // Write processed content to a new markdown file
    fs.writeFileSync("processedMarkdown.md", markdown);
    console.log("Markdown processed successfully");
  } catch (error) {
    console.error("Error processing markdown:", error);
  }
}

const markdownFileName =
  "🎯直播 Live 第 140 场：重新理解产品内核 - 飞书云文档";

// Example usage
const basePath = path.join(__dirname, "workdir");
const markdownFilePath = path.join(basePath, `${markdownFileName}.md`);
const mediaPath = path.join(basePath, "media");

processMarkdown(markdownFilePath, mediaPath);
