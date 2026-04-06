import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import UpsertCategorySupport from "../components/upsert-category-support";

export default {
  name: "solved-category-type-tab",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    withPluginApi((api) => {
      api.registerEditCategoryTab({
        id: "support",
        name: i18n("solved.category_type_support.title"),
        primary: true,
        component: UpsertCategorySupport,
        condition: ({ category }) => {
          return (
            category.isType("support") &&
            siteSettings.enable_support_category_type_setup
          );
        },
      });
    });
  },
};
