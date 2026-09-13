import { captureAuth } from "./captureAuth";

function looksLikeUrl(value: string): boolean {
  return /^https?:\/\//i.test(value);
}

function parseArgs(argv: string[]) {
  let url: string | undefined;
  let configPath: string | undefined;
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--url" && argv[i + 1]) {
      url = argv[++i];
    } else if (arg === "--config" && argv[i + 1]) {
      configPath = argv[++i];
    } else if (arg === "--help" || arg === "-h") {
      console.log(`Usage: pnpm auth [url] [--url <url>] [--config <path>]

Open the target page in a visible browser, then write cookies + localStorage
into config.json after you finish logging in.
`);
      process.exit(0);
    } else if (!arg.startsWith("-") && looksLikeUrl(arg)) {
      url = arg;
    } else {
      console.error(`Unknown argument: ${arg}`);
      process.exit(1);
    }
  }
  return { url, configPath };
}

async function main() {
  const { url, configPath } = parseArgs(process.argv.slice(2));
  try {
    await captureAuth({ url, configPath });
  } catch (error) {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  }
}

main();
