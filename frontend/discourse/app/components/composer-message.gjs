import { applyMutableValueTransformer } from "discourse/lib/transformer";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import DominatingTopicComposerMessage from "./composer-messages/dominating-topic.gjs";
import EducationComposerMessage from "./composer-messages/education.gjs";
import GetARoomComposerMessage from "./composer-messages/get-a-room.gjs";
import GroupMentionedComposerMessage from "./composer-messages/group-mentioned.gjs";
import SimilarTopicsComposerMessage from "./composer-messages/similar-topics.gjs";

const COMPOSER_MESSAGES = {
  "dominating-topic": DominatingTopicComposerMessage,
  education: EducationComposerMessage,
  "get-a-room": GetARoomComposerMessage,
  "group-mentioned": GroupMentionedComposerMessage,
  "similar-topics": SimilarTopicsComposerMessage,
};

function getComposerMessageComponent(templateName) {
  const resolvedMessages = { ...COMPOSER_MESSAGES };
  applyMutableValueTransformer("composer-message-components", resolvedMessages);

  const result = resolvedMessages[templateName];

  if (!result) {
    // eslint-disable-next-line no-console
    console.error(
      `Composer message component not found for template name: ${templateName}`
    );
  }

  return result;
}

const ComposerMessage = <template>
  <div class={{dConcatClass "composer-popup" @message.extraClass}}>
    {{#let
      (getComposerMessageComponent @message.templateName)
      as |MessageComponent|
    }}
      {{#if MessageComponent}}
        <MessageComponent
          @closeMessage={{@closeMessage}}
          @message={{@message}}
          @shareModal={{@shareModal}}
          @switchPM={{this.switchPM}}
        />
      {{/if}}
    {{/let}}
  </div>
</template>;

export default ComposerMessage;
