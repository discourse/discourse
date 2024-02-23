import Component from "@glimmer/component";
import UserStatusMessage from "discourse/components/user-status-message";
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

  get interactive() {
    return this.args.interactive ?? false;
  }

  get showStatus() {
    return this.args.showStatus ?? false;
  }

  get showStatusDescription() {
    return this.args.showStatusDescription ?? false;
  }

  <template>
    {{#if @user}}
      <ChatUserAvatar
        @user={{@user}}
        @avatarSize={{this.avatarSize}}
        @interactive={{this.interactive}}
      />

      {{#if this.interactive}}
        <a href={{this.userPath}} data-user-card={{@user.username}}>
          <ChatUserDisplayName @user={{@user}} />
        </a>
      {{else}}
        <ChatUserDisplayName @user={{@user}} />
      {{/if}}

      {{#if this.showStatus}}
        <UserStatusMessage
          @status={{@user.status}}
          @showDescription={{this.showStatusDescription}}
        />
      {{/if}}
    {{/if}}
  </template>
}
