export const suits = ["clubs", "diamonds", "hearts", "spades"] as const;
export type StandardSuit = (typeof suits)[number];
export type Suit = StandardSuit | "joker";

export const rankValues = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16] as const;
export type RankValue = (typeof rankValues)[number];

export interface Card {
  id: string;
  suit: Suit;
  rank: RankValue;
}

export const rankLabelMap: Record<RankValue, string> = {
  3: "3",
  4: "4",
  5: "5",
  6: "6",
  7: "7",
  8: "8",
  9: "9",
  10: "10",
  11: "J",
  12: "Q",
  13: "K",
  14: "A",
  15: "2",
  16: "JKR"
};

const suitLabelMap: Record<Suit, string> = {
  clubs: "C",
  diamonds: "D",
  hearts: "H",
  spades: "S",
  joker: ""
};

const suitSortOrder: Record<Suit, number> = {
  clubs: 0,
  diamonds: 1,
  hearts: 2,
  spades: 3,
  joker: 4
};

export function cardLabel(card: Card): string {
  if (card.suit === "joker") {
    return rankLabelMap[card.rank];
  }

  return `${rankLabelMap[card.rank]}${suitLabelMap[card.suit]}`;
}

export function compareCards(a: Card, b: Card): number {
  if (a.rank !== b.rank) {
    return a.rank - b.rank;
  }

  return suitSortOrder[a.suit] - suitSortOrder[b.suit];
}

export function createDeck(): Card[] {
  const deck: Card[] = [];

  for (const rank of rankValues) {
    if (rank === 16) {
      continue;
    }

    for (const suit of suits) {
      deck.push({
        id: `${rank}-${suit}`,
        rank,
        suit
      });
    }
  }

  deck.push(
    {
      id: "16-joker-1",
      rank: 16,
      suit: "joker"
    },
    {
      id: "16-joker-2",
      rank: 16,
      suit: "joker"
    }
  );

  return deck;
}

export function isThreeOfClubs(card: Card): boolean {
  return card.rank === 3 && card.suit === "clubs";
}
