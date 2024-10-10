import RelatedMessages from "discourse/components/related-messages";
import SuggestedTopics from "discourse/components/suggested-topics";
import { withPluginApi } from "discourse/lib/plugin-api";
import i18n from "discourse-common/helpers/i18n";

export default {
  initialize() {
    withPluginApi("1.37.2", (api) => {
      api.registerMoreTopicsTab({
        id: "related-messages",
        name: i18n("related_messages.pill"),
        context: "pm",
        component: RelatedMessages,
        condition: ({ topic }) => topic.relatedMessages?.length > 0,
      });

      api.registerMoreTopicsTab({
        id: "suggested-topics",
        name: i18n("suggested_topics.pill"),
        context: "*",
        component: SuggestedTopics,
        condition: ({ topic }) => topic.suggestedTopics?.length > 0,
      });

      // a plugin example:
      // api.registerValueTransformer("more-topics-tabs", ({ value, context }) => {
      //   if (context.user?.aFeatureFlag) {
      //     // Remove "suggested" topics
      //     return value.filter(
      //       (tab) =>
      //         context.currentContext !== "topic" ||
      //         tab.id !== "suggested-topics"
      //     );
      //   } else {
      //     // Remove "related" topics
      //     return value.filter(
      //       (tab) =>
      //         context.currentContext !== "topic" ||
      //         tab.id !== "related-topics"
      //     );
      //   }
      // });
    });
  },
};
