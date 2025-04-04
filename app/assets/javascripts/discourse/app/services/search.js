import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { applyValueTransformer } from "discourse/lib/transformer";

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
    return applyValueTransformer(
      "site-setting-search-experience",
      this.siteSettings.search_experience
    );
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

      let links = document.querySelectorAll(".search-menu .results a");
      let results = document.querySelectorAll(
        ".search-menu .results .search-link"
      );

      if (!results.length) {
        return;
      }

      let prevResult;
      let result;

      links.forEach((item) => {
        if (item.classList.contains("search-link")) {
          prevResult = item;
        }

        if (item === focused) {
          result = prevResult;
        }
      });

      let index = -1;
      if (result) {
        index = Array.prototype.indexOf.call(results, result);
      }

      if (index === -1 && e.key === "ArrowDown") {
        // change focus from the search input to the first result item
        const firstResult = results[0] || links[0];
        firstResult.focus();
      } else if (index === 0 && e.key === "ArrowUp") {
        this.focusSearchInput();
      } else if (index > -1) {
        // change focus to the next result item if present
        index += e.key === "ArrowDown" ? 1 : -1;
        if (index >= 0 && index < results.length) {
          results[index].focus();
        }
      }

      e.stopPropagation();
      e.preventDefault();
      return false;
    }
  }
}
