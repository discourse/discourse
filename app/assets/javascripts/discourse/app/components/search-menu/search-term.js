import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { isiPad } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";
import {
  DEFAULT_TYPE_FILTER,
  SEARCH_INPUT_ID,
  focusSearchButton,
} from "discourse/components/search-menu";

const SECOND_ENTER_MAX_DELAY = 15000;

export default class SearchTerm extends Component {
  @service search;
  @service appEvents;

  @tracked lastEnterTimestamp = null;

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
  }

  @action
  focus(element) {
    element.focus();
    element.select();
  }

  @action
  onKeyup(e) {
    if (e.key === "Escape") {
      focusSearchButton();
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
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
      if (!e.target.value) {
        this.args.clearTopicContext();
        this.args.clearPMInboxContext();
        this.focus(e.target);
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
