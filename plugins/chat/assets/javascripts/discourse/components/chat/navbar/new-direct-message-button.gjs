import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";

export default class ChatNavbarNewDirectMessageButton extends Component {
  @service router;
  @service modal;
  @service chat;

  buttonLabel = i18n("chat.channels_list_popup.browse");

  get showButtonComponent() {
    return (
      this.router.currentRoute.name === "chat.direct-messages" &&
      this.canCreateDirectMessageChannel
    );
  }

  get canCreateDirectMessageChannel() {
    return this.chat.userCanDirectMessage;
  }

  @action
  openNewMessageModal() {
    this.modal.show(ChatModalNewMessage);
  }

  <template>
    {{#if this.showButtonComponent}}
      <DButton
        class="btn no-text btn-flat c-navbar__new-dm-button"
        title={{this.buttonLabel}}
        @action={{this.openNewMessageModal}}
        @icon="plus"
      />
    {{/if}}
  </template>
}
