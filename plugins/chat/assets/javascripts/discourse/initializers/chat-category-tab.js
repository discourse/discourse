import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import LazyCategoryChat from "discourse/plugins/chat/discourse/components/upsert-category/lazy-chat";

export default {
  name: "chat-category-tab",

  initialize() {
    withPluginApi((api) => {
      api.registerEditCategoryTab({
        id: "chat",
        name: i18n("chat.edit_category.tab_title"),
        component: LazyCategoryChat,
        condition: ({ category, siteSettings }) =>
          siteSettings.chat_enabled && category.id,
      });
    });
  },
};
