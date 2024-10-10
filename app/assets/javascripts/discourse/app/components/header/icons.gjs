import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DAG from "discourse/lib/dag";
import getURL from "discourse-common/lib/get-url";
import Dropdown from "./dropdown";
import UserDropdown from "./user-dropdown";

let headerIcons;
resetHeaderIcons();

function resetHeaderIcons() {
  headerIcons = new DAG({ defaultPosition: { before: "search" } });
  headerIcons.add("search");
  headerIcons.add("hamburger", undefined, { after: "search" });
  headerIcons.add("user-menu", undefined, { after: "hamburger" });
}

export function headerIconsDAG() {
  return headerIcons;
}

export function clearExtraHeaderIcons() {
  resetHeaderIcons();
}

export default class Icons extends Component {
  @service site;
  @service currentUser;
  @service siteSettings;
  @service sidebarState;
  @service header;
  @service search;

  get showHamburger() {
    // NOTE: In this scenario, we are forcing the sidebar on admin users,
    // so we need to still show the hamburger menu to be able to
    // access the legacy hamburger forum menu.
    if (this.header.headerButtonsHidden.includes("menu")) {
      return false;
    }

    if (
      this.args.sidebarEnabled &&
      this.sidebarState.adminSidebarAllowedWithLegacyNavigationMenu
    ) {
      return true;
    }

    return !this.args.sidebarEnabled || this.site.mobileView;
  }

  get hideSearchButton() {
    return this.header.headerButtonsHidden.includes("search");
  }

  @action
  toggleHamburger() {
    if (this.sidebarState.adminSidebarAllowedWithLegacyNavigationMenu) {
      this.args.toggleNavigationMenu("hamburger");
    } else {
      this.args.toggleNavigationMenu();
    }
  }

  <template>
    <ul class="icons d-header-icons">
      {{#each (headerIcons.resolve) as |entry|}}
        {{#if (eq entry.key "search")}}
          {{#unless this.hideSearchButton}}
            <Dropdown
              @title="search.title"
              @icon="magnifying-glass"
              @iconId={{@searchButtonId}}
              @onClick={{@toggleSearchMenu}}
              @active={{this.search.visible}}
              @href={{getURL "/search"}}
              @className="search-dropdown"
              @targetSelector=".search-menu-panel"
            />
          {{/unless}}
        {{else if (eq entry.key "hamburger")}}
          {{#if this.showHamburger}}
            <Dropdown
              @title="hamburger_menu"
              @icon="bars"
              @iconId="toggle-hamburger-menu"
              @active={{this.header.hamburgerVisible}}
              @onClick={{this.toggleHamburger}}
              @className="hamburger-dropdown"
            />
          {{/if}}
        {{else if (eq entry.key "user-menu")}}
          {{#if this.currentUser}}
            <UserDropdown
              @active={{this.header.userVisible}}
              @toggleUserMenu={{@toggleUserMenu}}
            />
          {{/if}}
        {{else if entry.value}}
          <entry.value />
        {{/if}}
      {{/each}}
    </ul>
  </template>
}
