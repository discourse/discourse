import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import { userPath } from "discourse/lib/url";
import DUserStatusMessage from "discourse/ui-kit/d-user-status-message";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";
import ChatUserDisplayName from "discourse/plugins/chat/discourse/components/chat-user-display-name";

export default class ChatUserInfo extends Component {
  trackUserStatus = modifier((element, [user]) => {
    user.statusManager.trackStatus();

    return () => {
      user.statusManager.stopTrackingStatus();
    };
  });

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
        @avatarSize={{this.avatarSize}}
        @interactive={{this.interactive}}
        @user={{@user}}
      />

      {{#if this.interactive}}
        <a data-user-card={{@user.username}} href={{this.userPath}}>
          <ChatUserDisplayName @user={{@user}} />
        </a>
      {{else}}
        <ChatUserDisplayName @user={{@user}} />
      {{/if}}

      {{#if this.showStatus}}
        <div class="user-status" {{this.trackUserStatus @user}}>
          <DUserStatusMessage
            @showDescription={{this.showStatusDescription}}
            @status={{@user.status}}
          />
        </div>
      {{/if}}
    {{/if}}
  </template>
}
