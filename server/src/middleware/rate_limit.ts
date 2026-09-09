export interface RateLimiter { allow(key: string, now?: number): boolean; }

export class MemoryRateLimiter implements RateLimiter {
  private readonly entries = new Map<string, { start: number; count: number }>();
  constructor(private readonly limit: number, private readonly windowMs: number) {}

  allow(key: string, now = Date.now()): boolean {
    const entry = this.entries.get(key);
    if (!entry || now - entry.start >= this.windowMs) {
      this.entries.set(key, { start: now, count: 1 });
      return true;
    }
    if (entry.count >= this.limit) return false;
    entry.count++;
    return true;
  }
}
