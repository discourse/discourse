import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";

export default class ChatNavbarOpenDrawerButton extends Component {
  @service chatStateManager;
  @service pageShell;
  @service site;

  @action
  async openDrawer() {
    this.chatStateManager.prefersDrawer();

    DiscourseURL.routeTo(this.chatStateManager.lastKnownAppURL).then(() => {
      DiscourseURL.routeTo(this.chatStateManager.lastKnownChatURL);
    });
  }

  <template>
    {{#if this.site.desktopView}}
      <DButton
        class="c-navbar__open-drawer-button btn-transparent"
        @action={{this.openDrawer}}
        @icon={{if
          this.pageShell.canOpenContext
          "table-columns"
          "discourse-compress"
        }}
        @label={{if this.pageShell.canOpenContext "chat.panel_view"}}
        @title={{if
          this.pageShell.canOpenContext
          "chat.panel_view"
          "chat.close_full_page"
        }}
      />
    {{/if}}
  </template>
}
