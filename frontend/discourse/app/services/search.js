import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

@disableImplicitInjections
export default class Search extends Service {
  @service appEvents;
  @service siteSettings;

  @tracked activeGlobalSearchTerm = "";
  @tracked searchContext;
  @tracked highlightTerm;
  @tracked inTopicContext = false;
  @tracked visible = false;
  @tracked results = {};
  @tracked noResults = false;
  @tracked welcomeBannerSearchInViewport = false;

  // only relative for the widget search menu
  searchContextEnabled = false; // checkbox to scope search

  get currentSearchInputId() {
    if (this.welcomeBannerSearchInViewport) {
      return "welcome-banner-search-input";
    } else if (this.searchExperience === "search_field") {
      return "header-search-input";
    } else {
      return "icon-search-input";
    }
  }

  get searchExperience() {
    return this.siteSettings.search_experience;
  }

  focusSearchInput() {
    document.getElementById(this.currentSearchInputId)?.focus();
  }

  get contextType() {
    return this.searchContext?.type || null;
  }

  // The need to navigate with the keyboard creates a lot shared logic
  // between multiple components
  //
  // - SearchTerm
  // - Results::AssistantItem
  // - Results::Types
  // - Results::MoreLink
  // - Results::RecentSearches
  //
  // To minimize the duplicate logic we will create a shared action here
  // that can be reused across all of the components
  @action
  handleResultInsertion(e) {
    if (e.keyCode === 65 /* a or A */) {
      // add a link and focus composer if open
      if (document.querySelector("#reply-control.open")) {
        this.appEvents.trigger(
          "composer:insert-text",
          document.activeElement.href,
          {
            ensureSpace: true,
          }
        );
        this.appEvents.trigger("header:keyboard-trigger", { type: "search" });
        document.querySelector("#reply-control.open textarea").focus();

        e.stopPropagation();
        e.preventDefault();
        return false;
      }
    }
  }

  @action
  handleArrowUpOrDown(e) {
    if (e.key === "ArrowUp" || e.key === "ArrowDown") {
      let focused = e.target.closest(".search-menu") ? e.target : null;
      if (!focused) {
        return;
      }

      const focusableItems = document.querySelectorAll(
        ".search-menu .results a, .search-menu .results [data-search-menu-navigation-item]"
      );
      const navigationItems = document.querySelectorAll(
        ".search-menu .results .search-link, .search-menu .results [data-search-menu-navigation-item]"
      );

      if (!navigationItems.length) {
        return;
      }

      let previousNavigationItem;
      let navigationItem;

      focusableItems.forEach((item) => {
        if (
          item.classList.contains("search-link") ||
          item.hasAttribute("data-search-menu-navigation-item")
        ) {
          previousNavigationItem = item;
        }

        if (item === focused) {
          navigationItem = previousNavigationItem;
        }
      });

      let index = -1;
      if (navigationItem) {
        index = Array.prototype.indexOf.call(navigationItems, navigationItem);
      }

      if (index === -1 && e.key === "ArrowDown") {
        // change focus from the search input to the first navigation item
        const firstResult = navigationItems[0] || focusableItems[0];
        firstResult.focus();
      } else if (index === 0 && e.key === "ArrowUp") {
        this.focusSearchInput();
      } else if (index > -1) {
        // change focus to the next navigation item if present
        index += e.key === "ArrowDown" ? 1 : -1;
        if (index >= 0 && index < navigationItems.length) {
          navigationItems[index].focus();
        }
      }

      e.stopPropagation();
      e.preventDefault();
      return false;
    }
  }
}
