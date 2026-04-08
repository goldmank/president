export interface RulesConfig {
  minPlayers: number;
  maxPlayers: number;
  clearOnTwo: boolean;
}

export const defaultRulesConfig: RulesConfig = {
  minPlayers: 3,
  maxPlayers: 8,
  clearOnTwo: false
};
