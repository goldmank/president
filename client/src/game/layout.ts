import type { PublicGameState } from "@president/shared";

export interface SeatLayout {
  x: number;
  y: number;
}

export interface TableLayout {
  topSeats: SeatLayout[];
  viewerSeat: SeatLayout;
  topSeatScale: number;
  center: SeatLayout;
  handY: number;
  actionBarY: number;
  logBox: { x: number; y: number; width: number; height: number };
  contentWidth: number;
  trayWidth: number;
  trayTop: number;
  trayHeight: number;
  centerPanelWidth: number;
  centerPanelHeight: number;
  requirementY: number;
  statusY: number;
  tableFrame: { x: number; y: number; width: number; height: number; radius: number };
  handSpread: number;
  isTablet: boolean;
}

function buildRingSeatPositions(playerCount: number): SeatLayout[] {
  if (playerCount <= 0) {
    return [];
  }

  const startAngle = Math.PI / 2;
  const angleStep = (Math.PI * 2) / playerCount;

  return Array.from({ length: playerCount }, (_value, index) => {
    const angle = startAngle + angleStep * index;

    return {
      x: Math.cos(angle),
      y: Math.sin(angle)
    };
  });
}

export function computeTableLayout(width: number, height: number, state: PublicGameState): TableLayout {
  const opponents = state.players.filter((player) => player.id !== state.viewerPlayerId);
  const isTablet = width >= 700;
  const contentWidth = Math.min(width - 28, isTablet ? 700 : 420);
  const trayWidth = Math.min(width - 24, isTablet ? contentWidth : contentWidth + 8);
  const trayHeight = Math.max(176, Math.min(228, height * (isTablet ? 0.22 : 0.24)));
  const trayTop = height - trayHeight - Math.max(14, height * 0.02);
  const center = {
    x: width / 2,
    y: Math.max(196, Math.min(height * 0.375, trayTop - (isTablet ? 188 : 156)))
  };
  const normalizedPositions = buildRingSeatPositions(state.players.length);
  const topSeatScale = Math.max(0.74, Math.min(1, (isTablet ? 1.04 : 0.98) - Math.max(0, opponents.length - 4) * 0.08));
  const seatOrbitRadius = Math.max(
    102,
    Math.min(
      188,
      Math.max(contentWidth * 0.23, height * 0.17),
      center.y - 54,
      trayTop + 18 - center.y
    )
  );
  const positions: SeatLayout[] = normalizedPositions.map((position) => ({
    x: center.x + position.x * seatOrbitRadius,
    y: center.y + position.y * seatOrbitRadius
  }));
  const viewerSeat = positions[0] ?? { x: width / 2, y: center.y + seatOrbitRadius };
  const topSeats = positions.slice(1);

  return {
    topSeats,
    viewerSeat,
    topSeatScale,
    center,
    handY: height - Math.max(48, trayHeight * 0.18),
    actionBarY: trayTop + 16,
    logBox: {
      x: width / 2,
      y: trayTop - (isTablet ? 40 : 26),
      width: Math.min(contentWidth, isTablet ? 520 : width - 32),
      height: Math.min(108, height * 0.12)
    },
    contentWidth,
    trayWidth,
    trayTop,
    trayHeight,
    centerPanelWidth: Math.min(contentWidth * (isTablet ? 0.48 : 0.54), isTablet ? 360 : 300),
    centerPanelHeight: isTablet ? 198 : 176,
    requirementY: Math.max(44, height * 0.065),
    statusY: 22,
    tableFrame: {
      x: (width - contentWidth) / 2,
      y: 24,
      width: contentWidth,
      height: trayTop - 40,
      radius: isTablet ? 48 : 36
    },
    handSpread: Math.min(isTablet ? 48 : 36, Math.max(24, contentWidth / 10)),
    isTablet
  };
}
