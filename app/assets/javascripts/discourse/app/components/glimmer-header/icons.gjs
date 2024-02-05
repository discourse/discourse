import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";
import not from "truth-helpers/helpers/not";
import or from "truth-helpers/helpers/or";
import MountWidget from "../mount-widget";
import Dropdown from "./dropdown";
import UserDropdown from "./user-dropdown";

let _extraHeaderIcons = [];

export function addToHeaderIcons(icon) {
  _extraHeaderIcons.push(icon);
}

export function clearExtraHeaderIcons() {
  _extraHeaderIcons = [];
}

export default class Icons extends Component {
  @service site;
  @service currentUser;

  <template>
    <ul class="icons d-header-icons">
      {{#each _extraHeaderIcons as |icon|}}
        <MountWidget @widget={{icon}} />
        {{! I am not sure how we are going to render glimmer components here without
        being able to import them. }}
      {{/each}}

      <Dropdown
        @title="search.title"
        @icon="search"
        @iconId={{@searchButtonId}}
        @onClick={{@toggleSearchMenu}}
        @active={{@searchVisible}}
        @href={{getURL "/search"}}
        @className="search-dropdown"
        @targetSelector=".search-menu-panel"
      />

      {{#if (or (not @sidebarEnabled) this.site.mobileView)}}
        <Dropdown
          @title="hamburger_menu"
          @icon="bars"
          @iconId="toggle-hamburger-menu"
          @active={{@hamburgerVisible}}
          @onClick={{@toggleHamburger}}
          @href=""
          @className="hamburger-dropdown"
        />
      {{/if}}

      {{#if this.currentUser}}
        <UserDropdown
          @active={{@userVisible}}
          @toggleUserMenu={{@toggleUserMenu}}
        />
      {{/if}}
    </ul>
  </template>
}
