import EmbedMode from "discourse/lib/embed-mode";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  after: "inject-objects",

  initialize() {
    if (!EmbedMode.enabled) {
      return;
    }

    withPluginApi((api) => {
      api.registerValueTransformer(
        "post-menu-buttons",
        ({ value: dag, context: { post, buttonKeys, buttonLabels } }) => {
          if (post.post_number !== 1) {
            return;
          }

          // The embedding page shows the first post's content, so its menu is
          // reduced to the like button plus summary-style controls plugins add
          // alongside it (e.g. a reactions summary).
          const coreKeys = Object.values(buttonKeys);

          dag.entries().forEach(([key, ButtonComponent]) => {
            const isPluginSummary =
              !coreKeys.includes(key) && ButtonComponent.extraControls;

            if (key !== buttonKeys.LIKE && !isPluginSummary) {
              dag.delete(key);
            }
          });

          buttonLabels.show(buttonKeys.LIKE);
        }
      );
    });
  },
};
