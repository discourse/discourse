import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DiscourseURL from "discourse/lib/url";

export default class ChatNavbarSidePanelButton extends Component {
  @service chat;
  @service chatStateManager;
  @service site;

  get showButton() {
    return this.site.desktopView;
  }

  get isSidePanelActive() {
    return this.chatStateManager.isSidePanelMode;
  }

  @action
  toggleSidePanel() {
    if (this.isSidePanelActive) {
      // Switch from side panel to drawer mode
      this.chatStateManager.prefersDrawer();
      this.chatStateManager.isSidePanelMode = false;
    } else if (this.chatStateManager.isDrawerActive) {
      // Switch from drawer to side panel mode
      this.chatStateManager.prefersSidePanel();
      this.chatStateManager.isSidePanelMode = true;
    } else {
      // From full page: switch to side panel
      this.chatStateManager.prefersSidePanel();
      this.chat.activeChannel = null;

      DiscourseURL.routeTo(this.chatStateManager.lastKnownAppURL).then(() => {
        DiscourseURL.routeTo(this.chatStateManager.lastKnownChatURL);
      });
    }
  }

  <template>
    {{#if this.showButton}}
      <DButton
        @icon="discourse-sidebar"
        @action={{this.toggleSidePanel}}
        @title={{if
          this.isSidePanelActive
          "chat.side_panel.switch_to_drawer"
          "chat.side_panel.open"
        }}
        class={{if
          this.isSidePanelActive
          "btn-transparent no-text c-navbar__side-panel-button --active"
          "btn-transparent no-text c-navbar__side-panel-button"
        }}
      />
    {{/if}}
  </template>
}
