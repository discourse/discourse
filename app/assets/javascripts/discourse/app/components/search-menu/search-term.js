import Component from "@glimmer/component";
import discourseDebounce from "discourse-common/lib/debounce";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { isiPad } from "discourse/lib/utilities";
import { DEFAULT_TYPE_FILTER } from "discourse/components/search-menu";
import { inject as service } from "@ember/service";

const SECOND_ENTER_MAX_DELAY = 15000;

export default class SearchTerm extends Component {
  @service search;
  @service appEvents;

  @tracked lastEnterTimestamp = null;

  @action
  updateSearchTerm(input) {
    // utilze discourseDebounce as @debounce does not work for native class syntax
    discourseDebounce(
      this,
      this.parseAndUpdateSearchTerm,
      this.search.activeGlobalSearchTerm,
      input,
      200
    );
  }

  @action
  focus(element) {
    element.focus();
    element.select();
  }

  @action
  onKeyup(e) {
    if (e.key === "Escape") {
      document.querySelector("#search-button").focus();
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
    }

    if (this.loading) {
      return;
    }

    this.search.handleArrowUpOrDown(e);

    if (e.key === "Enter") {
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
        this.args.closeSearchMenu();
      } else {
        this.args.updateTypeFilter(null);
        this.args.triggerSearch();
      }
      this.lastEnterTimestamp = Date.now();
    }

    if (e.key === "Backspace") {
      if (!document.querySelector("#search-term").value) {
        this.args.clearTopicContext();
        this.args.clearPMInboxContext();
        this.focus(e.target);
      }
    }
  }

  parseAndUpdateSearchTerm(originalVal, newVal) {
    // remove zero-width chars
    const parsedVal = newVal.target.value.replace(/[\u200B-\u200D\uFEFF]/, "");

    if (parsedVal !== originalVal) {
      this.args.searchTermChanged(parsedVal);
    }
  }
}
