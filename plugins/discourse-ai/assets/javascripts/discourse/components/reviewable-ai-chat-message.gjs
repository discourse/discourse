import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewablePostHeader from "discourse/components/reviewable-post-header";
import { optionalRequire } from "discourse/lib/utilities";
import { or } from "discourse/truth-helpers";
import ModelAccuracies from "./model-accuracies";

export default class ReviewableAiChatMessage extends Component {
  get chatChannel() {
    if (!this.args.reviewable.chat_channel) {
      return;
    }

    const ChatChannel = optionalRequire(
      "discourse/plugins/chat/discourse/models/chat-channel"
    );

    return ChatChannel.create(this.args.reviewable.chat_channel);
  }

  get ChatChannelTitle() {
    return optionalRequire(
      "discourse/plugins/chat/discourse/components/chat-channel-title"
    );
  }

  <template>
    {{#if this.chatChannel}}
      <div class="flagged-post-header">
        <LinkTo
          @route="chat.channel.near-message"
          @models={{array
            this.chatChannel.slugifiedTitle
            this.chatChannel.id
            @reviewable.target_id
          }}
        >
          <this.ChatChannelTitle @channel={{this.chatChannel}} />
        </LinkTo>
      </div>
    {{/if}}

    <div class="post-contents-wrapper">
      <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />
      <div class="post-contents">
        <ReviewablePostHeader
          @reviewable={{@reviewable}}
          @createdBy={{@reviewable.target_created_by}}
        />

        <div class="post-body">
          {{htmlSafe
            (or @reviewable.payload.message_cooked @reviewable.cooked)
          }}
        </div>

        {{yield}}

        <ModelAccuracies @accuracies={{@reviewable.payload.accuracies}} />
      </div>
    </div>
  </template>
}
