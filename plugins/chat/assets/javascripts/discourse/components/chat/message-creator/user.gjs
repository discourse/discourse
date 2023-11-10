import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import userStatus from "discourse/helpers/user-status";
import I18n from "discourse-i18n";
import gt from "truth-helpers/helpers/gt";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";
import ChatUserDisplayName from "discourse/plugins/chat/discourse/components/chat-user-display-name";

export default class ChatableUser extends Component {
  @service currentUser;

  disabledUserLabel = I18n.t("chat.new_message_modal.disabled_user");

  <template>
    <div class="chat-message-creator__chatable-user">
      <ChatUserAvatar @user={{@item.model}} @interactive={{false}} />
      <ChatUserDisplayName @user={{@item.model}} />

      {{#if (gt @item.tracking.unreadCount 0)}}
        <div class="unread-indicator -urgent"></div>
      {{/if}}

      {{userStatus @item.model currentUser=this.currentUser}}

      {{#unless @item.enabled}}
        <span class="disabled-text">
          {{this.disabledUserLabel}}
        </span>
      {{/unless}}
    </div>
  </template>
}
