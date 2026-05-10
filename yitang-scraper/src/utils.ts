import { fileURLToPath } from 'url';
import { dirname } from 'path';

export function getDir(metaUrl: string) {
    const __filename = fileURLToPath(metaUrl);
    return dirname(__filename);
}