import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { i18n } from "discourse-i18n";
import Notifications from "./user-dropdown/notifications";

export default class UserDropdown extends Component {
  @service currentUser;

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
      id="current-user"
      class={{concatClass
        (if @active "active")
        "header-dropdown-toggle current-user user-menu-panel"
      }}
    >
      <PluginOutlet @name="user-dropdown-button__before" />
      <button
        id="toggle-current-user"
        class="icon btn-flat"
        aria-haspopup="true"
        aria-expanded={{@active}}
        aria-label={{i18n
          "user.account_possessive"
          name=(or this.currentUser.name this.currentUser.username)
        }}
        {{on "click" this.click}}
      >
        <Notifications @active={{@active}} />
      </button>
      <PluginOutlet @name="user-dropdown-button__after" />
    </li>
  </template>
}
