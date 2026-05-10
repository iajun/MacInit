/** Run async tasks over items with at most `concurrency` in flight. */
export async function runPool<T>(
    items: T[],
    concurrency: number,
    worker: (item: T, index: number) => Promise<void>
): Promise<void> {
    const limit = Math.max(1, Math.min(concurrency, items.length || 1));
    let next = 0;

    async function runWorker() {
        while (true) {
            const i = next++;
            if (i >= items.length) return;
            await worker(items[i], i);
        }
    }

    await Promise.all(Array.from({ length: Math.min(limit, items.length) }, () => runWorker()));
}
