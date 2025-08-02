import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import ThreadSettingsModal from "discourse/plugins/chat/discourse/components/chat/modal/thread-settings";

export default class ChatNavbarThreadSettingsButton extends Component {
  @service currentUser;
  @service modal;

  get canChangeThreadSettings() {
    if (!this.args.thread) {
      return false;
    }

    return (
      this.currentUser.staff ||
      this.currentUser.id === this.args.thread.originalMessage.user.id
    );
  }

  @action
  openThreadSettings() {
    this.modal.show(ThreadSettingsModal, { model: this.args.thread });
  }

  <template>
    {{#if this.canChangeThreadSettings}}
      <DButton
        @action={{this.openThreadSettings}}
        @icon="gear"
        @title="chat.thread.settings"
        class="btn-transparent c-navbar__thread-settings-button"
      />
    {{/if}}
  </template>
}
