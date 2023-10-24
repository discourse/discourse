import Component from "@glimmer/component";
import { userPath } from "discourse/lib/url";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";
import ChatUserDisplayName from "discourse/plugins/chat/discourse/components/chat-user-display-name";

export default class ChatUserInfo extends Component {
  get avatarSize() {
    return this.args.avatarSize ?? "medium";
  }

  get userPath() {
    return userPath(this.args.user.username);
  }

  <template>
    {{#if @user}}
      <a href={{this.userPath}} data-user-card={{@user.username}}>
        <ChatUserAvatar @user={{@user}} @avatarSize={{this.avatarSize}} />
      </a>
      <a href={{this.userPath}} data-user-card={{@user.username}}>
        <ChatUserDisplayName @user={{@user}} />
      </a>
    {{/if}}
  </template>
}
