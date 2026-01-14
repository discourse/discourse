import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import ReviewableCreatedBy from "discourse/components/reviewable-refresh/created-by";
import ReviewableTopicLink from "discourse/components/reviewable-refresh/topic-link";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import { i18n } from "discourse-i18n";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import ModelAccuracies from "../model-accuracies";

export default class ReviewableRefreshAiChatMessage extends Component {
  @cached
  get channel() {
    if (!this.args.reviewable.chat_channel) {
      return;
    }
    return ChatChannel.create(this.args.reviewable.chat_channel);
  }

  get messageCooked() {
    return (
      this.args.reviewable.payload?.message_cooked ||
      this.args.reviewable.cooked
    );
  }

  <template>
    <div class="review-item__meta-content">
      <div class="review-item__meta-label">{{i18n
          "chat.reviewable.message_in_channel"
        }}</div>

      <div class="review-item__meta-topic-title">
        {{#if this.channel}}
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
        {{else}}
          <ReviewableTopicLink @reviewable={{@reviewable}} @tagName="" />
        {{/if}}
      </div>

      <div class="review-item__meta-label">{{i18n "review.review_user"}}</div>

      <div class="review-item__meta-flagged-user">
        <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />
      </div>
    </div>

    <div class="review-item__post">
      <div class="review-item__post-content-wrapper">
        <div class="review-item__post-content">
          {{highlightWatchedWords this.messageCooked @reviewable}}

          {{#if @reviewable.payload.transcript_topic_id}}
            <div class="transcript">
              <LinkTo
                @route="topic"
                @models={{array "-" @reviewable.payload.transcript_topic_id}}
                class="btn btn-default btn-small"
              >
                {{i18n "review.transcript.view"}}
              </LinkTo>
            </div>
          {{/if}}

          <ModelAccuracies @accuracies={{@reviewable.payload.accuracies}} />

          {{yield}}
        </div>
      </div>
    </div>
  </template>
}
