import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class ChatNavbarToggleDrawerButton extends Component {
  @service chat;
  @service chatStateManager;

  <template>
    <DButton
      @icon={{if
        this.chatStateManager.isDrawerExpanded
        "angles-down"
        "angles-up"
      }}
      @action={{this.chat.toggleDrawer}}
      @title={{if
        this.chatStateManager.isDrawerExpanded
        "chat.collapse"
        "chat.expand"
      }}
      class="btn-transparent no-text c-navbar__toggle-drawer-button"
    />
  </template>
}
