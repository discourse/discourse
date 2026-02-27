import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import CategoryChat from "discourse/plugins/chat/discourse/components/upsert-category/chat";

export default {
  name: "chat-category-tab",

  initialize() {
    withPluginApi((api) => {
      api.registerEditCategoryTab({
        id: "chat",
        name: i18n("chat.edit_category.tab_title"),
        component: CategoryChat,
        condition: ({ category, siteSettings }) =>
          siteSettings.chat_enabled &&
          category.id &&
          siteSettings.enable_simplified_category_creation,
      });
    });
  },
};
