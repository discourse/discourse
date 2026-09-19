import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import PluginOutlet from "discourse/components/plugin-outlet";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import Notifications from "./user-dropdown/notifications";

export default class UserDropdown extends Component {
  @action
  click(e) {
    if (wantsNewWindow(e)) {
      return;
    }
    e.preventDefault();
    this.args.toggleUserMenu();

    // remove the focus of the header dropdown button after clicking
    e.target.tagName.toLowerCase() === "button"
      ? e.target.blur()
      : e.target.closest("button").blur();
  }

  <template>
    <li
      class={{dConcatClass
        (if @active "active")
        "header-dropdown-toggle current-user user-menu-panel"
      }}
      id="current-user"
    >
      <PluginOutlet @name="user-dropdown-button__before" />
      <DButton
        aria-expanded={{@active}}
        aria-haspopup="true"
        aria-label={{i18n "user.avatar.header_title"}}
        class="icon btn-flat"
        id="toggle-current-user"
        title={{i18n "user.avatar.header_title"}}
        {{on "click" this.click}}
      >
        <Notifications @active={{@active}} />
      </DButton>
      <PluginOutlet @name="user-dropdown-button__after" />
    </li>
  </template>
}
