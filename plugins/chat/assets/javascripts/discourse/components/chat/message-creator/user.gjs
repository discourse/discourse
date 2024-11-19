import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { not } from "truth-helpers";
import UserStatusMessage from "discourse/components/user-status-message";
import concatClass from "discourse/helpers/concat-class";
import userStatus from "discourse/helpers/user-status";
import { i18n } from "discourse-i18n";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";
import ChatUserDisplayName from "discourse/plugins/chat/discourse/components/chat-user-display-name";

export default class ChatableUser extends Component {
  @service currentUser;

  disabledUserLabel = i18n("chat.new_message_modal.disabled_user");

  trackUserStatus = modifier((element, [user]) => {
    user.statusManager.trackStatus();

    return () => {
      user.statusManager.stopTrackingStatus();
    };
  });

  get showIndicator() {
    return this.isUrgent || this.isUnread;
  }

  get isUrgent() {
    return (
      this.args.item.tracking.unreadCount +
        this.args.item.tracking.mentionCount +
        this.args.item.tracking.watchedThreadsUnreadCount >
      0
    );
  }

  get isUnread() {
    return this.args.item.unread_thread_count > 0;
  }

  <template>
    <div
      class="chat-message-creator__chatable -user"
      data-disabled={{not @item.enabled}}
    >
      <ChatUserAvatar @user={{@item.model}} @interactive={{false}} />
      <ChatUserDisplayName @user={{@item.model}} />

      {{#if this.showIndicator}}
        <div
          class={{concatClass "unread-indicator" (if this.isUrgent "-urgent")}}
        ></div>
      {{/if}}

      {{userStatus @item.model currentUser=this.currentUser}}

      <div class="user-status" {{this.trackUserStatus @item.model}}>
        <UserStatusMessage
          @status={{@item.model.status}}
          @showDescription={{true}}
        />
      </div>

      {{#unless @item.enabled}}
        <span class="chat-message-creator__disabled-warning">
          {{this.disabledUserLabel}}
        </span>
      {{/unless}}
    </div>
  </template>
}
