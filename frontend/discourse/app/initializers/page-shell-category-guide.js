import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "page-shell-category-guide",
  after: "freeze-block-registry",

  initialize() {
    withPluginApi((api) => {
      api.renderBlocks("category-guide", [
        { block: "category-hot-topics" },
        { block: "category-leaderboard" },
      ]);
    });
  },
};
