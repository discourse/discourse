import Component from "@glimmer/component";
import discourseDebounce from "discourse-common/lib/debounce";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { isiPad } from "discourse/lib/utilities";
import { DEFAULT_TYPE_FILTER } from "discourse/widgets/search-menu";

export default class SearchTerm extends Component {
  @tracked lastEnterTimestamp = null;

  @action
  updateSearchTerm(input) {
    // utilze discourseDebounce as @debounce does not work for native class syntax
    discourseDebounce(
      this,
      this.parseAndUpdateSearchTerm,
      this.args.value,
      input,
      200
    );
  }

  parseAndUpdateSearchTerm(originalVal, newVal) {
    // remove zero-width chars
    const parsedVal = newVal.target.value.replace(/[\u200B-\u200D\uFEFF]/, "");

    if (parsedVal !== originalVal) {
      this.args.searchTermChanged(parsedVal);
    }
  }

  @action
  keyDown(e) {
    if (e.key === "Escape") {
      this.sendWidgetAction("toggleSearchMenu");
      document.querySelector("#search-button").focus();
      e.preventDefault();
      return false;
    }

    if (this.loading) {
      return;
    }

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

          e.preventDefault();
          document.querySelector("#reply-control.open textarea").focus();
          return false;
        }
      }
    }

    const up = e.key === "ArrowUp";
    const down = e.key === "ArrowDown";
    if (up || down) {
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

      if (index === -1 && down) {
        document.querySelector(".search-menu .results .search-link").focus();
      } else if (index === 0 && up) {
        document.querySelector(".search-menu input#search-term").focus();
      } else if (index > -1) {
        index += down ? 1 : -1;
        if (index >= 0 && index < results.length) {
          results[index].focus();
        }
      }

      e.preventDefault();
      return false;
    }

    const searchInput = document.querySelector("#search-term");
    if (e.key === "Enter" && e.target === searchInput) {
      const recentEnterHit =
        this.lastEnterTimestamp &&
        Date.now() - this.lastEnterTimestamp < SECOND_ENTER_MAX_DELAY;

      // same combination as key-enter-escape mixin
      if (
        e.ctrlKey ||
        e.metaKey ||
        (isiPad() && e.altKey) ||
        (this.args.typeFilter !== DEFAULT_TYPE_FILTER && recentEnterHit)
      ) {
        this.args.fullSearch();
      } else {
        this.args.updateTypeFilter(null);
        this.args.triggerSearch();
      }
      this.lastEnterTimestamp = Date.now();
    }

    if (e.target === searchInput && e.key === "Backspace") {
      if (!searchInput.value) {
        this.args.clearTopicContext();
        this.args.clearPMInboxContext();
      }
    }
  }
}
