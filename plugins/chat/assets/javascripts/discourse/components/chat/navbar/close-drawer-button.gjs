import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class ChatNavbarCloseDrawerButton extends Component {
  @service chat;
  @service chatStateManager;

  @action
  closeDrawer() {
    this.chatStateManager.didCloseDrawer();
    this.chat.activeChannel = null;
  }

  <template>
    <DButton
      @icon="xmark"
      @action={{this.closeDrawer}}
      @title="chat.close"
      class="btn-transparent no-text c-navbar__close-drawer-button"
    />
  </template>
}
