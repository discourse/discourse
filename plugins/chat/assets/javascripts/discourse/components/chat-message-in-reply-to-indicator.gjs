import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { MESSAGE_CONTEXT_THREAD } from "discourse/plugins/chat/discourse/components/chat-message";
import ChatEmojiAvatar from "./chat-emoji-avatar.gjs";
import ChatUserAvatar from "./chat-user-avatar.gjs";

export default class ChatMessageInReplyToIndicator extends Component {
  @cached
  get linkTarget() {
    if (this.args.context === MESSAGE_CONTEXT_THREAD) {
      return "thread-near-message";
    }
    if (
      this.args.message?.channel?.threadingEnabled &&
      this.args.message?.thread?.id
    ) {
      return "thread";
    }
    return "channel-near-message";
  }

  get route() {
    switch (this.linkTarget) {
      case "thread-near-message":
        return "chat.channel.thread.near-message";
      case "thread":
        return "chat.channel.thread";
      default:
        return "chat.channel.near-message";
    }
  }

  get model() {
    const { message } = this.args;
    switch (this.linkTarget) {
      case "thread-near-message":
        return [...message.thread.routeModels, message.inReplyTo.id];
      case "thread":
        return [...message.thread.routeModels];
      default:
        return [...message.channel.routeModels, message.inReplyTo.id];
    }
  }

  <template>
    {{#if @message.inReplyTo}}
      <LinkTo
        class="chat-reply is-direct-reply"
        @models={{this.model}}
        @route={{this.route}}
      >
        {{dIcon "share" title="chat.in_reply_to"}}

        {{#if @message.inReplyTo.chatWebhookEvent.emoji}}
          <ChatEmojiAvatar
            @emoji={{@message.inReplyTo.chatWebhookEvent.emoji}}
          />
        {{else}}
          <ChatUserAvatar @user={{@message.inReplyTo.user}} />
        {{/if}}

        <span class="chat-reply__excerpt">
          {{dReplaceEmoji (trustHTML @message.inReplyTo.excerpt)}}
        </span>
      </LinkTo>
    {{/if}}
  </template>
}
