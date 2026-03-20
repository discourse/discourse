import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import ChatThreadParticipants from "./chat-thread-participants";
import ChatUserAvatar from "./chat-user-avatar";

export default class ChatMessageThreadIndicator extends Component {
  get interactiveUser() {
    return this.args.interactiveUser ?? true;
  }

  get threadMessageRoute() {
    return [
      ...this.args.message.thread.routeModels,
      this.args.message.thread.preview.lastReplyId,
    ];
  }

  <template>
    <LinkTo
      class="chat-message-thread-indicator"
      @route="chat.channel.thread.near-message"
      @models={{this.threadMessageRoute}}
      title={{i18n "chat.threads.open"}}
      tabindex="0"
      ...attributes
    >
      <div class="chat-message-thread-indicator__last-reply-avatar">
        <ChatUserAvatar
          @user={{@message.thread.preview.lastReplyUser}}
          @avatarSize="small"
          @interactive={{this.interactiveUser}}
        />
      </div>

      <div class="chat-message-thread-indicator__last-reply-info">
        <span class="chat-message-thread-indicator__last-reply-username">
          {{@message.thread.preview.lastReplyUser.username}}
        </span>
        <span class="chat-message-thread-indicator__last-reply-timestamp">
          {{dFormatDate
            @message.thread.preview.lastReplyCreatedAt
            leaveAgo="true"
          }}
        </span>
      </div>
      <div class="chat-message-thread-indicator__replies-count">
        {{i18n "chat.thread.replies" count=@message.thread.preview.replyCount}}
      </div>
      <ChatThreadParticipants @thread={{@message.thread}} />
      <div class="chat-message-thread-indicator__last-reply-excerpt">
        {{dReplaceEmoji (trustHTML @message.thread.preview.lastReplyExcerpt)}}
      </div>
    </LinkTo>
  </template>
}
