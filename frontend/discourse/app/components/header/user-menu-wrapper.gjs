import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { animateClosing } from "discourse/lib/animation-utils";
import closeOnClickOutside from "../../modifiers/close-on-click-outside";
import UserMenu from "../user-menu/menu";

export default class UserMenuWrapper extends Component {
  @service header;
  @service site;

  @tracked userMenuWrapper;

  @action
  async clickOutside() {
    this.toggleUserMenu();
  }

  @action
  setupWrapper(el) {
    this.userMenuWrapper = el.querySelector(".menu-panel.drop-down");
  }

  @action
  async toggleUserMenu() {
    const wasVisible = this.header.userVisible;
    const willBeVisible = !wasVisible;
    const isClosing = wasVisible && !willBeVisible;
    if (isClosing && this.site.desktopView) {
      await animateClosing(this.userMenuWrapper);
    }
    this.args.toggleUserMenu();
  }

  <template>
    <div
      class="user-menu-dropdown-wrapper"
      {{didInsert this.setupWrapper}}
      {{closeOnClickOutside
        this.clickOutside
        (hash
          targetSelector=".user-menu-panel"
          secondaryTargetSelector=".user-menu-panel"
        )
      }}
      ...attributes
    >
      <UserMenu @closeUserMenu={{this.toggleUserMenu}} />
    </div>
  </template>
}
