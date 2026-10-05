export class MatchmakingQueue {
  private readonly waiting: string[] = [];

  join(playerId: string): void {
    if (!this.waiting.includes(playerId)) this.waiting.push(playerId);
  }

  leave(playerId: string): void {
    const index = this.waiting.indexOf(playerId);
    if (index >= 0) this.waiting.splice(index, 1);
  }

  takePair(): [string, string] | null {
    if (this.waiting.length < 2) return null;
    const first = this.waiting.shift();
    const second = this.waiting.shift();
    return first !== undefined && second !== undefined ? [first, second] : null;
  }
}

