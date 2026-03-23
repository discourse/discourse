import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import UpsertCategoryIdeas from "../components/upsert-category-ideas";

export default {
  name: "ideas-category-type-tab",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    withPluginApi((api) => {
      api.registerEditCategoryTab({
        id: "ideas",
        name: i18n("topic_voting.category_type_ideas.title"),
        primary: true,
        component: UpsertCategoryIdeas,
        condition: ({ category }) => {
          return (
            category.isType("ideas") &&
            siteSettings.enable_ideas_category_type_setup
          );
        },
      });
    });
  },
};
