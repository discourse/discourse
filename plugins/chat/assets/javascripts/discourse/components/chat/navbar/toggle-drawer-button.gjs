import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";

export default class ChatNavbarToggleDrawerButton extends Component {
  @service chat;
  @service chatStateManager;

  <template>
    <DButton
      class="btn-transparent no-text c-navbar__toggle-drawer-button"
      @action={{this.chat.toggleDrawer}}
      @icon={{if this.chatStateManager.isDrawerExpanded "minus" "angles-up"}}
      @title={{if
        this.chatStateManager.isDrawerExpanded
        "chat.collapse"
        "chat.expand"
      }}
    />
  </template>
}
