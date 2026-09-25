import { withPluginApi } from "discourse/lib/core-api";
import { i18n } from "discourse-i18n";

export default {
  initialize() {
    withPluginApi((api) => {
      api.registerMoreTopicsTab({
        id: "related-messages",
        name: i18n("related_messages.pill"),
        component: () => import("discourse/components/related-messages"),
        condition: ({ context, topic }) =>
          context === "pm" && topic.relatedMessages?.length > 0,
      });

      api.registerMoreTopicsTab({
        id: "suggested-topics",
        name: i18n("suggested_topics.pill"),
        component: () => import("discourse/components/suggested-topics"),
        condition: ({ topic }) => topic.suggestedTopics?.length > 0,
      });
    });
  },
};
