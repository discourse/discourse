import { withPluginApi } from "discourse/lib/plugin-api";
import GamificationLeaderboardBlock from "../blocks/gamification-leaderboard";

export default {
  name: "discourse-gamification:register-visual-editor-blocks",
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(GamificationLeaderboardBlock);
    });
  },
};
