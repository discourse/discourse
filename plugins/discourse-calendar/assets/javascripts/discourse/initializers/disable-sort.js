import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "disable-sort",

  initialize(container) {
    withPluginApi("0.8", (api) => {
      api.registerValueTransformer(
        "topic-list-header-sortable-column",
        ({ value, context }) => {
          if (!value) {
            return value;
          }

          const siteSettings = container.lookup("service:site-settings");
          return !(
            siteSettings.disable_resorting_on_categories_enabled &&
            context.category?.custom_fields?.disable_topic_resorting
          );
        }
      );
    });
  },
};
