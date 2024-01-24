import Component from "@glimmer/component";
import { action } from "@ember/object";
import or from "truth-helpers/helpers/or";
import { concat } from "@ember/helper";
import i18n from "discourse-common/helpers/i18n";
import Notifications from "./notifications";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { inject as service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import { on } from "@ember/modifier";

export default class UserDropdown extends Component {
  @service currentUser;

  @action
  click(e) {
    if (wantsNewWindow(e)) {
      return;
    }
    e.preventDefault();
    this.args.toggleUserMenu();
  }

  <template>
    <li
      id="current-user"
      class={{concatClass
        (if @active "active")
        "header-dropdown-toggle current-user user-menu-panel"
      }}
      {{on "click" this.click}}
    >
      <button
        class="icon btn-flat"
        aria-haspopup="true"
        aria-expanded={{@active}}
        href={{this.currentUser.path}}
        aria-label={{concat
          (or this.currentUser.name this.currentUser.username)
          (i18n "user.account_possessive")
        }}
        data-auto-route="true"
      >
        <Notifications @active={{@active}} />
      </button>

    </li>
  </template>
}
