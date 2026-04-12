/**
 * yitang 课程小节：支持
 * - https://yitang.top/lesson/section/83
 * - https://yitang.top/lesson/section/83,24,55
 */
const SECTION_PATH = /^\/lesson\/section\/([^/]+)$/;

export function parseYitangLessonSectionUrl(input: string): { origin: string; sectionIds: string[] } | null {
    let u: URL;
    try {
        u = new URL(input.trim());
    } catch {
        return null;
    }

    const host = u.hostname.toLowerCase();
    if (host !== "yitang.top" && !host.endsWith(".yitang.top")) {
        return null;
    }

    const m = u.pathname.match(SECTION_PATH);
    if (!m) return null;

    const sectionIds = m[1]
        .split(",")
        .map((s) => s.trim())
        .filter((s) => s.length > 0);

    if (sectionIds.length === 0) return null;

    return { origin: u.origin, sectionIds };
}

export function isYitangLessonSectionUrl(input: string): boolean {
    return parseYitangLessonSectionUrl(input) !== null;
}
