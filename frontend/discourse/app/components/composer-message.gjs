import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { classNameBindings } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";
import discourseComputed from "discourse/lib/decorators";
import { applyMutableValueTransformer } from "discourse/lib/transformer";
import DominatingTopicComposerMessage from "./composer-messages/dominating-topic";
import EducationComposerMessage from "./composer-messages/education";
import GetARoomComposerMessage from "./composer-messages/get-a-room";
import GroupMentionedComposerMessage from "./composer-messages/group-mentioned";
import SimilarTopicsComposerMessage from "./composer-messages/similar-topics";

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
  <div class={{concatClass "composer-popup" @message.extraClass}}>
    {{#let
      (getComposerMessageComponent @message.templateName)
      as |MessageComponent|
    }}
      {{#if MessageComponent}}
        <MessageComponent
          @message={{@message}}
          @closeMessage={{@closeMessage}}
          @shareModal={{@shareModal}}
          @switchPM={{this.switchPM}}
        />
      {{/if}}
    {{/let}}
  </div>
</template>;

export default ComposerMessage;
