import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import dCloseOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import UserMenu from "../user-menu/menu";

export default class UserMenuWrapper extends Component {
  @action
  clickOutside(e) {
    if (e.target.classList.contains("header-cloak")) {
      return;
    }

    this.args.toggleUserMenu();
  }

  <template>
    <div
      class="user-menu-dropdown-wrapper"
      {{dCloseOnClickOutside
        this.clickOutside
        (hash
          targetSelector=".user-menu-panel"
          secondaryTargetSelector=".user-menu-panel"
        )
      }}
      ...attributes
    >
      <UserMenu @closeUserMenu={{fn @toggleUserMenu false}} />
    </div>
  </template>
}
