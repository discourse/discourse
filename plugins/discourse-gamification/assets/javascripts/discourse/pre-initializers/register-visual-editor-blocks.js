import { withPluginApi } from "discourse/lib/plugin-api";
import GamificationLeaderboardBlock from "../blocks/gamification-leaderboard";

/**
 * Registers gamification's visual-editor blocks. Runs as a
 * pre-initializer because the block registry is frozen by the
 * `freeze-block-registry` initializer; any `api.registerBlock(...)`
 * call after that point throws.
 *
 * `api.registerBlock` is a core Discourse API (not gated on the
 * visual editor plugin being installed), so no feature-detection
 * guard is needed.
 */
export default {
  name: "discourse-gamification:register-visual-editor-blocks",
  before: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.registerBlock(GamificationLeaderboardBlock);
    });
  },
};
