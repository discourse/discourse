import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class ChatNavbarToggleDrawerButton extends Component {
  @service appEvents;
  @service chatStateManager;

  @action
  toggleExpand() {
    this.chatStateManager.didToggleDrawer();
    this.appEvents.trigger(
      "chat:toggle-expand",
      this.chatStateManager.isDrawerExpanded
    );
  }

  <template>
    <DButton
      @icon={{if
        this.chatStateManager.isDrawerExpanded
        "angle-double-down"
        "angle-double-up"
      }}
      @action={{this.toggleExpand}}
      @title={{if
        this.chatStateManager.isDrawerExpanded
        "chat.collapse"
        "chat.expand"
      }}
      class="btn-flat no-text c-navbar__toggle-drawer-button"
    />
  </template>
}
