export const palette = {
  background: "#0F1113",
  surface: "#121416",
  surfaceLowest: "#0c0e10",
  surfaceLow: "#1a1c1e",
  surfaceContainer: "#1e2022",
  surfaceHigh: "#282a2c",
  surfaceHighest: "#333537",
  surfaceBright: "#38393c",
  text: "#e2e2e5",
  mutedText: "#c5c6ca",
  outline: "#8f9194",
  outlineVariant: "#44474a",
  primary: "#FFD700",
  primaryDim: "#9b8200",
  onPrimary: "#0F1113",
  secondary: "#C0C0C0",
  tertiary: "#CD7F32",
  danger: "#ffb4ab",
  dangerDim: "#93000a",
  selection: "#ffe16d"
};

export function toColorNumber(value: string): number {
  return Number.parseInt(value.replace("#", ""), 16);
}
