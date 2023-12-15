import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DiscourseURL from "discourse/lib/url";

export default class ChatNavbarOpenDrawerButton extends Component {
  @service chatStateManager;
  @service site;

  @action
  async openDrawer() {
    this.chatStateManager.prefersDrawer();

    try {
      await DiscourseURL.routeTo(this.chatStateManager.lastKnownAppURL);
      await DiscourseURL.routeTo(this.chatStateManager.lastKnownChatURL);
    } catch (error) {
      await DiscourseURL.routeTo("/");
    }
  }

  <template>
    {{#if this.site.desktopView}}
      <DButton
        @icon="discourse-compress"
        @title="chat.close_full_page"
        class="c-navbar__open-drawer-button btn-flat"
        @action={{this.openDrawer}}
      />
    {{/if}}
  </template>
}
