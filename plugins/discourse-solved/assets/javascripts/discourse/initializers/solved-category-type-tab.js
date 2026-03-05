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
        condition: ({ category }) => category.isType("support"),
      });
    });
  },
};
