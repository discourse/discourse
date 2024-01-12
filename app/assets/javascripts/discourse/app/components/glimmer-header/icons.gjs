import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { getURL } from "discourse-common/lib/get-url";
import Dropdown from "./dropdown";
import or from "truth-helpers/helpers/or";
import not from "truth-helpers/helpers/not";
import { array } from "@ember/helper";

let _extraHeaderIcons = [];

export function addToHeaderIcons(icon) {
  _extraHeaderIcons.push(icon);
}

export function clearExtraHeaderIcons() {
  _extraHeaderIcons = [];
}

export default class Icons extends Component {
  @service site;

  <template>
    <ul class="icons.d-header-icons">
      {{#each _extraHeaderIcons as |icon|}}
        {{icon}}
      {{/each}}

      <Dropdown
        @title="search.title"
        @icon="search"
        @iconId="SEARCH_BUTTON_ID"
        @action={{@toggleSearchMenu}}
        @active={{@searchVisible}}
        @href={{getURL "/search"}}
        @classNames={{array "search-dropdown"}}
      />

      {{#if (or (not @sidebarEnabled) this.site.mobileView)}}
        <Dropdown
          @title="hamburger_menu"
          @icon="bars"
          @iconId="toggle-hamburger-menu"
          @active={{@hamburgerVisible}}
          @action={{@toggleHamburger}}
          @href=""
          @classNames={{array "hamburger-dropdown"}}
        />
      {{/if}}

      {{#if this.currentUser}}
        <UserDropdown @active={{@userVisible}} @action={{@toggleUserMenu}} />
      {{/if}}
    </ul>
  </template>
}

createWidget("header-icons", {
  services: ["search"],
  tagName: "ul.icons.d-header-icons",

  html(attrs) {
    if (this.siteSettings.login_required && !this.currentUser) {
      return [];
    }

    const icons = [];

    if (_extraHeaderIcons) {
      _extraHeaderIcons.forEach((icon) => {
        icons.push(this.attach(icon));
      });
    }

    const search = this.attach("header-dropdown", {
      title: "search.title",
      icon: "search",
      iconId: SEARCH_BUTTON_ID,
      action: "toggleSearchMenu",
      active: attrs.searchVisible || this.search.visible,
      href: getURL("/search"),
      classNames: ["search-dropdown"],
    });

    icons.push(search);

    const hamburger = this.attach("header-dropdown", {
      title: "hamburger_menu",
      icon: "bars",
      iconId: "toggle-hamburger-menu",
      active: attrs.hamburgerVisible,
      action: "toggleHamburger",
      href: "",
      classNames: ["hamburger-dropdown"],
    });

    if (!attrs.sidebarEnabled || this.site.mobileView) {
      icons.push(hamburger);
    }

    if (attrs.user) {
      icons.push(
        this.attach("user-dropdown", {
          active: attrs.userVisible,
          action: "toggleUserMenu",
          user: attrs.user,
        })
      );
    }

    return icons;
  },
});
