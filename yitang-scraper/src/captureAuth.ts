import { chromium, type Browser } from "playwright";
import fs from "fs";
import path from "path";
import readline from "readline";
import { getDir } from "./utils";

export type CapturedAuth = {
  cookies: Array<Record<string, unknown>>;
  localStorage: Record<string, string>;
  configPath: string;
};

const ROOT = path.join(getDir(import.meta.url), "..");
export const DEFAULT_CONFIG_PATH = path.join(ROOT, "config.json");
const EXAMPLE_CONFIG_PATH = path.join(ROOT, "config.example.json");

function waitForEnter(prompt: string): Promise<void> {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(prompt, () => {
      rl.close();
      resolve();
    });
  });
}

async function launchVisibleBrowser(): Promise<Browser> {
  // Prefer installed Chrome / Edge (often the system default); fall back to bundled Chromium.
  for (const channel of ["chrome", "msedge"] as const) {
    try {
      return await chromium.launch({ headless: false, channel });
    } catch {
      // try next
    }
  }
  return await chromium.launch({ headless: false });
}

function loadOrBootstrapConfig(configPath: string): Record<string, unknown> {
  if (fs.existsSync(configPath)) {
    return JSON.parse(fs.readFileSync(configPath, "utf-8")) as Record<
      string,
      unknown
    >;
  }
  if (fs.existsSync(EXAMPLE_CONFIG_PATH)) {
    const example = JSON.parse(
      fs.readFileSync(EXAMPLE_CONFIG_PATH, "utf-8")
    ) as Record<string, unknown>;
    const { cookies: _c, localStorage: _ls, ...rest } = example;
    return rest;
  }
  return {};
}

function resolveUrl(
  cfg: Record<string, unknown>,
  explicitUrl?: string
): string {
  if (explicitUrl?.trim()) return explicitUrl.trim();
  if (typeof cfg.url === "string" && cfg.url.trim()) return cfg.url.trim();
  if (Array.isArray(cfg.urls)) {
    const first = cfg.urls.find(
      (u): u is string => typeof u === "string" && u.trim().length > 0
    );
    if (first) return first.trim();
  }
  throw new Error(
    "缺少目标 URL：请在 config.json 设置 url / urls，或传入 --url"
  );
}

async function readLocalStorage(
  page: Awaited<ReturnType<Browser["newPage"]>>
): Promise<Record<string, string>> {
  return page.evaluate(() => {
    const out: Record<string, string> = {};
    for (let i = 0; i < window.localStorage.length; i++) {
      const key = window.localStorage.key(i);
      if (key != null) {
        out[key] = window.localStorage.getItem(key) ?? "";
      }
    }
    return out;
  });
}

/**
 * Open the target URL in a visible browser, wait for the user to finish login,
 * then write cookies + localStorage into config.json.
 *
 * Note: OS default browsers do not expose HttpOnly cookies to scripts; we launch
 * Chrome/Edge/Chromium under Playwright so the full session can be captured.
 */
export async function captureAuth(options?: {
  url?: string;
  configPath?: string;
}): Promise<CapturedAuth> {
  const configPath = options?.configPath ?? DEFAULT_CONFIG_PATH;
  const cfg = loadOrBootstrapConfig(configPath);
  const url = resolveUrl(cfg, options?.url);
  const origin = new URL(url).origin;

  const browser = await launchVisibleBrowser();
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    console.log(`Opening ${url}`);
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 120_000 });

    console.log(
      "已在浏览器中打开目标链接。请完成登录（确认能看到文档内容）后，回到终端按 Enter…"
    );
    await waitForEnter("> ");

    // Ensure we are on the target origin before reading storage.
    if (!page.url().startsWith(origin)) {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 120_000 });
    }

    const storage = await context.storageState();
    const cookies = storage.cookies as Array<Record<string, unknown>>;
    const fromState =
      storage.origins.find((o) => o.origin === origin)?.localStorage ?? [];
    const localStorage: Record<string, string> = {
      ...(await readLocalStorage(page)),
    };
    for (const item of fromState) {
      localStorage[item.name] = item.value;
    }

    if (cookies.length === 0 && Object.keys(localStorage).length === 0) {
      throw new Error(
        "未捕获到 cookie / localStorage，请确认已登录成功后重试"
      );
    }

    const next = {
      ...cfg,
      cookies,
      localStorage,
    };
    if (!next.url && !next.urls) {
      next.url = url;
    }

    fs.writeFileSync(configPath, `${JSON.stringify(next, null, 4)}\n`);
    console.log(
      `已写入 ${cookies.length} 个 cookie、${Object.keys(localStorage).length} 个 localStorage → ${configPath}`
    );

    return { cookies, localStorage, configPath };
  } finally {
    await browser.close();
  }
}

export function configHasAuth(cfg: {
  cookies?: unknown;
  localStorage?: Record<string, string>;
}): boolean {
  const hasCookies = Array.isArray(cfg.cookies) && cfg.cookies.length > 0;
  const hasLs =
    !!cfg.localStorage && Object.keys(cfg.localStorage).length > 0;
  return hasCookies || hasLs;
}
