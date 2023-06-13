import Service, { inject as service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

@disableImplicitInjections
export default class Search extends Service {
  @service appEvents;

  @tracked activeGlobalSearchTerm = "";
  @tracked searchContext;
  @tracked highlightTerm;

  // only relative for the widget search menu
  searchContextEnabled = false; // checkbox to scope search

  get contextType() {
    return this.searchContext?.type || null;
  }

  @action
  updateActiveGlobalSearchTerm(term) {
    this.activeGlobalSearchTerm = term;
  }

  @action
  setSearchContext(value) {
    this.searchContext = value;
  }

  @action
  setHighlightTerm(value) {
    this.highlightTerm = value;
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
  // To minimze the duplicate logic we will create a shared action here
  // that can be reused across all of the components
  @action
  handleResultInsertion(e) {
    if (e.which === 65 /* a */) {
      if (document.activeElement?.classList.contains("search-link")) {
        if (document.querySelector("#reply-control.open")) {
          // add a link and focus composer

          this.appEvents.trigger(
            "composer:insert-text",
            document.activeElement.href,
            {
              ensureSpace: true,
            }
          );
          this.appEvents.trigger("header:keyboard-trigger", { type: "search" });

          e.stopPropagation();
          e.preventDefault();
          document.querySelector("#reply-control.open textarea").focus();
          return false;
        }
      }
    }
  }

  @action
  handleArrowUpOrDown(e) {
    if (e.key === "ArrowUp" || e.key === "ArrowDown") {
      let focused = document.activeElement.closest(".search-menu")
        ? document.activeElement
        : null;

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
        document.querySelector(".search-menu .results .search-link").focus();
      } else if (index === 0 && e.key === "ArrowUp") {
        document.querySelector(".search-menu input#search-term").focus();
      } else if (index > -1) {
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
