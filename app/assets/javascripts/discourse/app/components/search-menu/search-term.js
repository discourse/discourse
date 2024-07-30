import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  DEFAULT_TYPE_FILTER,
  SEARCH_INPUT_ID,
} from "discourse/components/search-menu";
import { isiPad } from "discourse/lib/utilities";

const SECOND_ENTER_MAX_DELAY = 15000;

const onKeyUpCallbacks = [];

export function addOnKeyUpCallback(fn) {
  onKeyUpCallbacks.push(fn);
}
export function resetOnKeyUpCallbacks() {
  onKeyUpCallbacks.clear();
}

export default class SearchTerm extends Component {
  @service search;
  @service appEvents;

  @tracked lastEnterTimestamp = null;
  @tracked searchCleared = !this.search.activeGlobalSearchTerm;

  // make constant available in template
  get inputId() {
    return SEARCH_INPUT_ID;
  }

  @action
  updateSearchTerm(input) {
    this.parseAndUpdateSearchTerm(
      this.search.activeGlobalSearchTerm,
      input.target.value
    );

    this.searchCleared = this.search.activeGlobalSearchTerm ? false : true;
  }

  @action
  focus(element) {
    if (this.args.autofocus) {
      element.focus();
      element.select();
    }
  }

  @action
  onKeydown(e) {
    if (e.key === "Escape") {
      this.args.closeSearchMenu();
      e.preventDefault();
      e.stopPropagation();
    }
  }

  @action
  onKeyup(e) {
    if (
      onKeyUpCallbacks.length &&
      !onKeyUpCallbacks.some((fn) => fn(this, e))
    ) {
      // Return early if any callbacks return false
      return;
    }

    this.args.openSearchMenu();

    this.search.handleArrowUpOrDown(e);

    if (e.key === "Enter") {
      const recentEnterHit =
        this.lastEnterTimestamp &&
        Date.now() - this.lastEnterTimestamp < SECOND_ENTER_MAX_DELAY;

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
      if (!e.target.value) {
        // only clear context if we're not in the middle of a search
        if (this.searchCleared) {
          this.args.clearTopicContext();
          this.args.clearPMInboxContext();
          this.focus(e.target);
        }
        this.searchCleared = true;
      }
    }

    e.preventDefault();
  }

  parseAndUpdateSearchTerm(originalVal, newVal) {
    // remove zero-width chars
    const parsedVal = newVal.replace(/[\u200B-\u200D\uFEFF]/, "");
    if (parsedVal !== originalVal) {
      this.args.searchTermChanged(parsedVal);
    }
  }
}
