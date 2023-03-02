import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { generateCookFunction } from "discourse/lib/text";
import simpleCategoryHashMentionTransform from "discourse/plugins/chat/discourse/lib/simple-category-hash-mention-transform";

export default {
  name: "chat-cook-function",

  before: "chat-setup",

  initialize(container) {
    const site = container.lookup("service:site");

    const markdownOptions = {
      featuresOverride:
        site.markdown_additional_options?.chat?.limited_pretty_text_features,
      markdownItRules:
        site.markdown_additional_options?.chat
          ?.limited_pretty_text_markdown_rules,
      hashtagTypesInPriorityOrder: site.hashtag_configurations["chat-composer"],
      hashtagIcons: site.hashtag_icons,
    };

    generateCookFunction(markdownOptions).then((cookFunction) => {
      ChatMessage.cookFunction = (raw) => {
        return simpleCategoryHashMentionTransform(
          cookFunction(raw),
          site.categories
        );
      };
    });
  },
};
