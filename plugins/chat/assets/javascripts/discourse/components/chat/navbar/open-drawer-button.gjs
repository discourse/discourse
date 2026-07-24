import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";

export default class ChatNavbarOpenDrawerButton extends Component {
  @service chatStateManager;
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
        @icon="discourse-compress"
        @title="chat.close_full_page"
        class="c-navbar__open-drawer-button btn-transparent"
        @action={{this.openDrawer}}
      />
    {{/if}}
  </template>
}
