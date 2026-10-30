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
  get link() {
    const { message, context } = this.args;
    if (context === MESSAGE_CONTEXT_THREAD) {
      return {
        route: "chat.channel.thread.near-message",
        model: [...message.thread.routeModels, message.inReplyTo.id],
      };
    }
    if (message?.channel?.threadingEnabled && message?.thread?.id) {
      return {
        route: "chat.channel.thread",
        model: [...message.thread.routeModels],
      };
    }
    return {
      route: "chat.channel.near-message",
      model: [...message.channel.routeModels, message.inReplyTo.id],
    };
  }

  <template>
    {{#if @message.inReplyTo}}
      <LinkTo
        class="chat-reply is-direct-reply"
        @models={{this.link.model}}
        @route={{this.link.route}}
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
