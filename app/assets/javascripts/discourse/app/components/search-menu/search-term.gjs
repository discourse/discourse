import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { DEFAULT_TYPE_FILTER } from "discourse/components/search-menu";
import { isiPad } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

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

  <template>
    <input
      id={{@inputId}}
      class="search-term__input"
      type="search"
      autocomplete="off"
      enterkeyhint="search"
      value={{this.search.activeGlobalSearchTerm}}
      placeholder={{i18n "search.title"}}
      aria-label={{i18n "search.title"}}
      {{on "keyup" this.onKeyup}}
      {{on "keydown" this.onKeydown}}
      {{on "input" this.updateSearchTerm}}
      {{on "focus" @openSearchMenu}}
      {{didInsert this.focus}}
    />
  </template>
}
