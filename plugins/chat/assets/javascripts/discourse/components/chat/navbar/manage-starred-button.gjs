import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import ChatModalManageStarredChannels from "discourse/plugins/chat/discourse/components/chat/modal/manage-starred-channels";

export default class ChatNavbarManageStarredButton extends Component {
  @service modal;
  @service router;

  manageStarredLabel = i18n("chat.manage_starred_channels.title");

  get showManageStarredButton() {
    return this.router.currentRoute.name === "chat.starred-channels";
  }

  @action
  openModal() {
    this.modal.show(ChatModalManageStarredChannels);
  }

  <template>
    {{#if this.showManageStarredButton}}
      <DButton
        @action={{this.openModal}}
        @icon="pencil"
        @title={{this.manageStarredLabel}}
        class="btn no-text btn-flat c-navbar__manage-starred-button"
      />
    {{/if}}
  </template>
}
