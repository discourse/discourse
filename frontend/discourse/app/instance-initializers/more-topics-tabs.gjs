import RelatedMessages from "discourse/components/related-messages";
import SuggestedTopics from "discourse/components/suggested-topics";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  initialize() {
    withPluginApi((api) => {
      api.registerMoreTopicsTab({
        id: "related-messages",
        name: i18n("related_messages.pill"),
        component: RelatedMessages,
        condition: ({ context, topic }) =>
          context === "pm" && topic.relatedMessages?.length > 0,
      });

      api.registerMoreTopicsTab({
        id: "suggested-topics",
        name: i18n("suggested_topics.pill"),
        component: SuggestedTopics,
        condition: ({ topic }) => topic.suggestedTopics?.length > 0,
      });
    });
  },
};
