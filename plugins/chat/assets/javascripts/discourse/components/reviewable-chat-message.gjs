import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewablePostHeader from "discourse/components/reviewable-post-header";
import htmlSafe from "discourse-common/helpers/html-safe";
import i18n from "discourse-common/helpers/i18n";
import or from "truth-helpers/helpers/or";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatChannelTitle from "./chat-channel-title";

export default class ReviewableChatMessage extends Component {
  @service store;
  @service chatChannelsManager;

  @cached
  get chatChannel() {
    return ChatChannel.create(this.args.reviewable.chat_channel);
  }

  <template>
    <div class="flagged-post-header">
      <LinkTo
        @route="chat.channel.near-message"
        @models={{array
          this.chatChannel.slugifiedTitle
          this.chatChannel.id
          @reviewable.target_id
        }}
      >
        <ChatChannelTitle @channel={{this.chatChannel}} />
      </LinkTo>
    </div>

    <div class="post-contents-wrapper">
      <ReviewableCreatedBy
        @user={{@reviewable.target_created_by}}
        @tagName=""
      />
      <div class="post-contents">
        <ReviewablePostHeader
          @reviewable={{@reviewable}}
          @createdBy={{@reviewable.target_created_by}}
          @tagName=""
        />

        <div class="post-body">
          {{htmlSafe
            (or @reviewable.payload.message_cooked @reviewable.cooked)
          }}
        </div>

        {{#if @reviewable.payload.transcript_topic_id}}
          <div class="transcript">
            <LinkTo
              @route="topic"
              @models={{array "-" @reviewable.payload.transcript_topic_id}}
              class="btn btn-small"
            >
              {{i18n "review.transcript.view"}}
            </LinkTo>
          </div>
        {{/if}}

        {{yield}}
      </div>
    </div>
  </template>
}
