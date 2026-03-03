import { withPluginApi } from "discourse/lib/plugin-api";
import UpsertCategorySupport from "../components/upsert-category-support";

export default {
  name: "solved-category-type-tab",

  initialize() {
    withPluginApi((api) => {
      api.registerEditCategoryTab({
        id: "support",
        name: "Support",
        primary: true,
        component: UpsertCategorySupport,
        condition: ({ category, siteSettings }) =>
          // TODO (martin) We only populate the category_type on category creation
          // at the moment, we need to do the same in the serializer on edit
          category.get("category_type") === "support" &&
          siteSettings.enable_category_type_setup &&
          siteSettings.enable_simplified_category_creation,
      });
    });
  },
};
