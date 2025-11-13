// Default server address (can be configured via environment variable at build time)
const DEFAULT_ENDPOINT = import.meta.env.VITE_DEFAULT_ENDPOINT || 'https://note.lyb.pub';

export function getBlinkoEndpoint(path: string = ''): string {
    try {
        const blinkoEndpoint = window.localStorage.getItem('blinkoEndpoint')
        const isTauri = !!(window as any).__TAURI__;

        if (isTauri) {
            // Use user-configured endpoint, or default if not set
            const endpoint = blinkoEndpoint || DEFAULT_ENDPOINT;
            try {
                const url = new URL(path, endpoint.replace(/"/g, ''));
                console.debug('[Tauri] Using endpoint:', url.toString());
                return url.toString();
            } catch (error) {
                console.error('[Tauri] Invalid endpoint:', endpoint, error);
                return new URL(path, DEFAULT_ENDPOINT).toString();
            }
        }

        return new URL(path, window.location.origin).toString();
    } catch (error) {
        console.error('[getBlinkoEndpoint] Error:', error);
        return new URL(path, window.location.origin).toString();
    }
}

export function isTauriAndEndpointUndefined(): boolean {
    const isTauri = !!(window as any).__TAURI__;
    const blinkoEndpoint = window.localStorage.getItem('blinkoEndpoint')
    return isTauri && !blinkoEndpoint;
}

export function saveBlinkoEndpoint(endpoint: string): void {
    if (endpoint) {
        window.localStorage.setItem('blinkoEndpoint', endpoint);
    }
}

export function getSavedEndpoint(): string {
    return window.localStorage.getItem('blinkoEndpoint') || '';
}
