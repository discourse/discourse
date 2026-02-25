import { withPluginApi } from "discourse/lib/plugin-api";
import UpsertCategorySupport from "../components/upsert-category-support";

export default {
  name: "solved-category-type-tab",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.enable_simplified_category_creation) {
      return;
    }

    withPluginApi((api) => {
      api.registerEditCategoryTab({
        id: "support",
        name: "Support",
        primary: true,
        component: UpsertCategorySupport,
        condition: ({ category }) =>
          category.get("category_type") === "support",
      });
    });
  },
};
