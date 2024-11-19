import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { gt, not } from "truth-helpers";
import UserStatusMessage from "discourse/components/user-status-message";
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

  <template>
    <div
      class="chat-message-creator__chatable -user"
      data-disabled={{not @item.enabled}}
    >
      <ChatUserAvatar @user={{@item.model}} @interactive={{false}} />
      <ChatUserDisplayName @user={{@item.model}} />

      {{#if (gt @item.tracking.unreadCount 0)}}
        <div class="unread-indicator -urgent"></div>
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
