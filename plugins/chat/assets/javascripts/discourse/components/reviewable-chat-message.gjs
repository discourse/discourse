import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { or } from "truth-helpers";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewablePostHeader from "discourse/components/reviewable-post-header";
import { i18n } from "discourse-i18n";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ReviewableChatMessage extends Component {
  @service store;
  @service chatChannelsManager;

  @cached
  get channel() {
    if (!this.args.reviewable.chat_channel) {
      return;
    }
    return ChatChannel.create(this.args.reviewable.chat_channel);
  }

  <template>
    {{#if this.channel}}
      <div class="flagged-post-header">
        <LinkTo
          @route="chat.channel.near-message"
          @models={{array
            this.channel.slugifiedTitle
            this.channel.id
            @reviewable.target_id
          }}
        >
          <ChannelTitle @channel={{this.channel}} />
        </LinkTo>
      </div>
    {{/if}}

    <div class="post-contents-wrapper">
      <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />
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
