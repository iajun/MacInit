/**
 * Truncate HTML fragment at a heading whose plain text matches stopAtHeadingText.
 * Matches docx/fs-doc heading class patterns used elsewhere in this tool.
 */
function stripTags(html: string): string {
    return html
        .replace(/<script[\s\S]*?<\/script>/gi, "")
        .replace(/<style[\s\S]*?<\/style>/gi, "")
        .replace(/<[^>]+>/g, " ")
        .replace(/\s+/g, " ")
        .trim();
}

const STOP_MARKER = "<!--DOC_SCRAPER_STOP-->";

const HEADING_RE =
    /<([a-zA-Z0-9]+)([^>]*\bclass\s*=\s*"[^"]*(?:docx-heading(\d+)-block|heading(\d+))[^"]*"[^>]*)>([\s\S]*?)<\/\1>/g;

export function defaultStopAtHomeworkCandy(text: string, _level: number): boolean {
    return text.includes("作业") && text.includes("Candy");
}

export function truncateContentHtmlFragment(
    html: string,
    stopAtHeadingText: (text: string, level: number) => boolean = defaultStopAtHomeworkCandy
): { html: string; stopped: boolean } {
    let stopped = false;

    const replaced = html.replace(HEADING_RE, (full, _tagName, _attrs, lv1, lv2, inner) => {
        if (stopped) return "";
        const level = parseInt(lv1 || lv2, 10);
        if (!Number.isFinite(level) || level <= 0) return full;

        const text = stripTags(inner);
        if (text && stopAtHeadingText(text, level)) {
            stopped = true;
            return STOP_MARKER;
        }
        return full;
    });

    if (!stopped) return { html: replaced, stopped: false };

    const cutAt = replaced.indexOf(STOP_MARKER);
    const truncated = cutAt >= 0 ? replaced.slice(0, cutAt) : replaced;
    return { html: truncated, stopped: true };
}

/** Drop subsequent map entries after a fragment triggers stop (same order as convert.ts stream). */
export function truncateContentNodesMap(
    contentNodes: Map<string, string>,
    stopAtHeadingText?: (text: string, level: number) => boolean
): Map<string, string> {
    const out = new Map<string, string>();
    let stop = false;
    for (const [id, html] of contentNodes) {
        if (stop) break;
        const { html: h, stopped } = truncateContentHtmlFragment(html, stopAtHeadingText);
        out.set(id, h);
        if (stopped) stop = true;
    }
    return out;
}
