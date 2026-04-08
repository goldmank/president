import type { Card } from "@president/shared";

export function shuffle<T>(items: T[]): T[] {
  const cloned = [...items];

  for (let index = cloned.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    [cloned[index], cloned[swapIndex]] = [cloned[swapIndex], cloned[index]];
  }

  return cloned;
}

export function now(): number {
  return Date.now();
}

export function sortHand(cards: Card[]): Card[] {
  return [...cards].sort((left, right) => {
    if (left.rank !== right.rank) {
      return left.rank - right.rank;
    }

    return left.suit.localeCompare(right.suit);
  });
}
