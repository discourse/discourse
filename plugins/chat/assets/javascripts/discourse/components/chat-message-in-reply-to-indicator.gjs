import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import dIcon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import ChatEmojiAvatar from "./chat-emoji-avatar";
import ChatUserAvatar from "./chat-user-avatar";

export default class ChatMessageInReplyToIndicator extends Component {
  @service router;

  get route() {
    if (this.hasThread) {
      return "chat.channel.thread";
    } else {
      return "chat.channel.near-message";
    }
  }

  get model() {
    if (this.hasThread) {
      return [
        ...this.args.message.channel.routeModels,
        this.args.message.thread.id,
      ];
    } else {
      return [
        ...this.args.message.channel.routeModels,
        this.args.message.inReplyTo.id,
      ];
    }
  }

  get hasThread() {
    return (
      this.args.message?.channel?.threadingEnabled &&
      this.args.message?.thread?.id
    );
  }

  <template>
    {{#if @message.inReplyTo}}
      <LinkTo
        @route={{this.route}}
        @models={{this.model}}
        class="chat-reply is-direct-reply"
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
          {{replaceEmoji (htmlSafe @message.inReplyTo.excerpt)}}
        </span>
      </LinkTo>
    {{/if}}
  </template>
}
