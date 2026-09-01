import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import InterfaceColorSelector from "discourse/components/interface-color-selector";
import LanguageSwitcher from "discourse/components/language-switcher";
import { ALL_PAGES_EXCLUDED_ROUTES } from "discourse/components/welcome-banner";
import { languageSwitcherEnabled } from "discourse/lib/content-localization";
import DAG from "discourse/lib/dag";
import getURL from "discourse/lib/get-url";
import { eq } from "discourse/truth-helpers";
import Dropdown from "./dropdown";
import UserDropdown from "./user-dropdown";

let headerIcons;
resetHeaderIcons();

function resetHeaderIcons() {
  headerIcons = new DAG({ defaultPosition: { before: "search" } });
  headerIcons.add("search");
  headerIcons.add("hamburger", undefined, { after: "search" });
  headerIcons.add("user-menu", undefined, { after: "hamburger" });
  headerIcons.add("interface-color-selector", undefined, {
    before: "search",
    after: "language-switcher",
  });
  headerIcons.add("language-switcher", undefined, { before: "search" });
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
  @service navigationMenu;
  @service header;
  @service search;
  @service interfaceColor;
  @service router;

  get showHamburger() {
    // NOTE: In this scenario, we are forcing the sidebar on admin users,
    // so we need to still show the hamburger menu to be able to
    // access the legacy hamburger forum menu.
    if (this.header.headerButtonsHidden.includes("menu")) {
      return false;
    }

    if (this.args.sidebarEnabled && this.navigationMenu.isDesktopDropdownMode) {
      return true;
    }

    return !this.args.sidebarEnabled || this.site.mobileView;
  }

  get showSearchButton() {
    if (
      this.header.headerButtonsHidden.includes("search") ||
      ALL_PAGES_EXCLUDED_ROUTES.some(
        (name) => name === this.router.currentRouteName
      )
    ) {
      return false;
    }

    return (
      this.site.mobileView ||
      this.args.narrowDesktop ||
      (this.search.searchExperience === "search_icon" &&
        !this.search.welcomeBannerSearchInViewport) ||
      (this.search.searchExperience === "search_field" &&
        this.router.currentRouteName.startsWith("admin")) ||
      this.args.topicInfoVisible
    );
  }

  get showLanguageSwitcher() {
    if (!languageSwitcherEnabled(this.siteSettings)) {
      return false;
    }

    switch (this.siteSettings.content_localization_language_switcher) {
      case "anonymous":
        return !this.currentUser;
      case "all":
        return true;
      default:
        return false;
    }
  }

  @action
  toggleHamburger() {
    if (this.navigationMenu.isDesktopDropdownMode) {
      this.args.toggleNavigationMenu("hamburger");
    } else {
      this.args.toggleNavigationMenu();
    }
  }

  <template>
    <ul class="icons d-header-icons">
      {{#each (headerIcons.resolve) as |entry|}}
        {{#if (eq entry.key "search")}}
          {{#if this.showSearchButton}}
            <Dropdown
              class="search-dropdown"
              @active={{this.search.visible}}
              @href={{getURL "/search"}}
              @icon="magnifying-glass"
              @iconId={{@searchButtonId}}
              @onClick={{@toggleSearchMenu}}
              @onWillDestroy={{fn @toggleSearchMenu null false}}
              @title="search.title"
            />
          {{/if}}
        {{else if (eq entry.key "hamburger")}}
          {{#if this.showHamburger}}
            <Dropdown
              class="hamburger-dropdown"
              @active={{this.header.hamburgerVisible}}
              @icon="bars"
              @iconId="toggle-hamburger-menu"
              @onClick={{this.toggleHamburger}}
              @title="hamburger_menu"
            />
          {{/if}}
        {{else if (eq entry.key "user-menu")}}
          {{#if this.currentUser}}
            <UserDropdown
              @active={{this.header.userVisible}}
              @toggleUserMenu={{@toggleUserMenu}}
            />
          {{/if}}
        {{else if (eq entry.key "interface-color-selector")}}
          {{#if this.interfaceColor.selectorAvailableInHeader}}
            <li class="header-dropdown-toggle header-color-scheme-toggle">
              <InterfaceColorSelector />
            </li>
          {{/if}}
        {{else if (eq entry.key "language-switcher")}}
          {{#if this.showLanguageSwitcher}}
            <li class="header-dropdown-toggle language-switcher">
              <LanguageSwitcher />
            </li>
          {{/if}}
        {{else if entry.value}}
          <entry.value />
        {{/if}}
      {{/each}}
    </ul>
  </template>
}
