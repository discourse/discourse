import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import FilterNavigationToken from "discourse/components/discovery/filter-navigation-token";
import { VISIBILITY_OPTIMIZERS } from "discourse/float-kit/lib/constants";
import withEventValue from "discourse/helpers/with-event-value";
import discourseDebounce from "discourse/lib/debounce";
import {
  isCompleteSegment,
  splitCommittedSegments,
  splitFilterQuery,
} from "discourse/lib/filter-query-tokens";
import FilterSuggestions from "discourse/lib/filter-suggestions";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const FilterNavigationMenuList = <template>
  {{#if @data.suggestions.length}}
    <DDropdownMenu as |dropdown|>
      {{#each @data.suggestions as |item index|}}
        <dropdown.item
          class={{dConcatClass
            "filter-navigation__tip-item"
            (if (eq index @data.selectedIndex) "--selected")
          }}
          {{on "click" (fn @data.selectItem item)}}
        >
          {{#if item.category}}
            {{dCategoryBadge item.category allowUncategorized=true}}
          {{else}}
            <span class="filter-navigation__tip-name">
              {{item.name}}
            </span>

            {{#if item.description}}
              <span class="filter-navigation__tip-description">—
                {{item.description}}</span>
            {{/if}}
          {{/if}}
        </dropdown.item>
      {{/each}}
    </DDropdownMenu>
  {{/if}}
</template>;

/**
 * @typedef {{ name: string, description?: string, category?: import("discourse/models/category").default, term?: string, isSuggestion?: boolean, delimiters?: { name: string, description?: string }[], alias?: string, type?: string, priority?: number, prefixes?: { name: string, description?: string }[], extra_entries?: { name: string, description: string }[], min?: number }} FilterSuggestion
 */
/**
 * FilterNavigationMenu - A simpler UI component for filter input and suggestions
 *
 * This component manages:
 * - User input field
 * - Keyboard navigation
 * - Dropdown menu display
 * - Selection handling
 *
 * The actual suggestion generation is delegated to FilterSuggestions
 */
export default class FilterNavigationMenu extends Component {
  @service menu;
  @service site;

  /** Segments the user has finished typing, rendered as chips. */
  @tracked tokens = splitFilterQuery(this.args.initialInputValue);

  /** The segment still being typed in the input. */
  @tracked currentInputValue = "";

  /** @type {FilterSuggestion[]} */
  @tracked suggestions = [];

  /** @type {string | null} */
  @tracked activeFilter = null;

  lastSuggestionInput = "";
  suggestionRequestId = 0;

  /** @type {{ suggestions: FilterSuggestion[], selectedIndex: number | null, selectItem: FilterNavigationMenu["selectItem"] }} */
  trackedMenuListData = trackedObject({
    suggestions: [],
    selectedIndex: null,
    selectItem: this.selectItem,
  });

  /** @type {import("@ember/runloop").Timer | null} */
  searchTimer = null;

  /** @type {HTMLInputElement | null} */
  inputElement = null;

  /** @type {HTMLElement | null} */
  containerElement = null;

  /** @type {import("discourse/float-kit/lib/d-menu-instance").default | null | undefined} */
  dMenuInstance = null;
  _selectedIndex = -1;

  get selectedIndex() {
    return this._selectedIndex;
  }

  set selectedIndex(value) {
    this._selectedIndex = value;
    this.trackedMenuListData.selectedIndex = value;
  }

  get nothingSelected() {
    return this.selectedIndex === -1;
  }

  get placeholder() {
    if (this.tokens.length) {
      return i18n("filter.add_placeholder");
    }
    return this.args.placeholder || i18n("filter.placeholder");
  }

  get queryString() {
    return [...this.tokens, this.currentInputValue.trim()]
      .filter(Boolean)
      .join(" ");
  }

  get hasValue() {
    return this.tokens.length > 0 || !!this.currentInputValue;
  }

  clearSelection() {
    this.selectedIndex = -1;
  }

  @action
  storeInputElement(element) {
    this.inputElement = element;
  }

  @action
  storeContainerElement(element) {
    this.containerElement = element;
  }

  @action
  focusInputFromContainer(event) {
    if (event.target === this.containerElement) {
      this.inputElement?.focus();
    }
  }

  @action
  removeToken(index) {
    this.tokens = this.tokens.filter((_, i) => i !== index);
    this.#submitTokens();
    this.inputElement?.focus();
  }

  @action
  replaceToken(index, raw) {
    this.tokens = this.tokens.map((token, i) => (i === index ? raw : token));
    this.#submitTokens();
  }

  @action
  async editToken(index) {
    const raw = this.tokens[index];
    this.tokens = this.tokens.filter((_, i) => i !== index);
    await this.updateInput(raw);
    this.inputElement?.focus();
  }

  @action
  async updateSuggestions() {
    cancel(this.searchTimer);
    this.searchTimer = discourseDebounce(this, this.fetchSuggestions, 300);
  }

  async fetchSuggestions() {
    const input = this.currentInputValue || "";
    const requestId = ++this.suggestionRequestId;

    try {
      const result = await FilterSuggestions.getSuggestions(
        input,
        this.args.tips,
        {
          site: this.site,
        }
      );

      // Drop stale responses or results for outdated input
      if (
        requestId !== this.suggestionRequestId ||
        this.currentInputValue !== input
      ) {
        return;
      }

      this.suggestions = result.suggestions || [];
      this.activeFilter = result.activeFilter;
      this.trackedMenuListData.suggestions = this.suggestions;
      this.trackedMenuListData.selectedIndex = this.selectedIndex;
      this.clearSelection();
      this.lastSuggestionInput = input;

      if (this.dMenuInstance) {
        if (!this.suggestions.length) {
          this.dMenuInstance.close();
        } else {
          this.dMenuInstance.show();
        }
      }
    } catch {
      // ignore fetch errors (rate limits, etc)
    }
  }

  async ensureFreshSuggestions() {
    if (this.lastSuggestionInput === (this.currentInputValue || "")) {
      return;
    }

    cancel(this.searchTimer);
    this.searchTimer = null;

    await this.fetchSuggestions();
  }

  @action
  async selectItem(item) {
    const words = this.currentInputValue.split(/\s+/);
    let newValue;

    if (item.isSuggestion) {
      // Replace the last word with the selected suggestion
      words[words.length - 1] = item.name;
      newValue = words.join(" ");

      // a chosen value becomes a token; more values are added from its editor
      if (isCompleteSegment(item.name)) {
        newValue += " ";
      }
    } else {
      // Selecting a filter tip - add it to the input
      words[words.length - 1] = item.name;

      // Don't add space if this filter uses delimiters
      if (!item.name.endsWith(":") && !item.delimiters?.length) {
        words[words.length - 1] += " ";
      }

      newValue = words.join(" ");
    }

    await this.updateInput(newValue);
    this.inputElement?.focus();
  }

  @action
  async updateInput(value) {
    const { committed, draft } = splitCommittedSegments(value);

    if (committed.length) {
      this.tokens = [...this.tokens, ...committed];
    }
    this.currentInputValue = draft;
    this.clearSelection();

    this.args.onChange(this.queryString, false);
    await this.updateSuggestions();
  }

  @action
  async clearInput() {
    cancel(this.searchTimer);
    this.tokens = [];
    this.currentInputValue = "";
    this.clearSelection();
    this.args.onChange("", true);
    await this.ensureFreshSuggestions();
    this.inputElement?.focus();
  }

  @action
  async openFilterMenu() {
    if (this.dMenuInstance) {
      this.dMenuInstance.show();
      return;
    }

    await this.fetchSuggestions();

    this.dMenuInstance = await this.menu.show(this.containerElement, {
      identifier: "filter-navigation-menu-list",
      component: FilterNavigationMenuList,
      data: this.trackedMenuListData,
      matchTriggerWidth: true,
      visibilityOptimizer: VISIBILITY_OPTIMIZERS.NONE,
      constrainHeightToViewport: true,
      crossAxisShift: false, // NOTE: this should not be needed, but is. Without it when shrinking window autocomplete renders on top of input
      minHeight: 80,
    });

    if (!this.suggestions.length) {
      this.dMenuInstance.close();
    }
  }

  @action
  async handleKeydown(event) {
    if (
      this.suggestions.length === 0 &&
      ["ArrowDown", "ArrowUp", "Tab"].includes(event.key)
    ) {
      return;
    }

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        this.navigateDown();
        break;

      case "ArrowUp":
        event.preventDefault();
        this.navigateUp();
        break;

      case "Tab":
        event.preventDefault();
        event.stopPropagation();
        await this.ensureFreshSuggestions();
        this.selectCurrent();
        break;

      case " ":
        if (!this.dMenuInstance) {
          this.openFilterMenu();
        }
        break;

      case "Enter":
        if (this.selectedIndex >= 0) {
          event.preventDefault();
          event.stopPropagation();
          await this.ensureFreshSuggestions();
          this.selectCurrent();
        } else {
          this.submitQuery();
        }
        break;

      case "Escape":
        this.dMenuInstance?.close();
        break;

      case "Backspace":
        if (
          this.tokens.length &&
          this.inputElement?.selectionStart === 0 &&
          this.inputElement?.selectionEnd === 0
        ) {
          event.preventDefault();
          await this.editToken(this.tokens.length - 1);
        }
        break;
    }
  }

  navigateDown() {
    if (this.nothingSelected) {
      this.selectedIndex = 0;
    } else {
      this.selectedIndex = (this.selectedIndex + 1) % this.suggestions.length;
    }
    this.trackedMenuListData.selectedIndex = this.selectedIndex;
  }

  navigateUp() {
    if (this.nothingSelected) {
      this.selectedIndex = this.suggestions.length - 1;
    } else {
      this.selectedIndex =
        (this.selectedIndex - 1 + this.suggestions.length) %
        this.suggestions.length;
    }
    this.trackedMenuListData.selectedIndex = this.selectedIndex;
  }

  selectCurrent() {
    const index = this.nothingSelected ? 0 : this.selectedIndex;
    if (this.suggestions[index]) {
      this.selectItem(this.suggestions[index]);
    }
  }

  async submitQuery() {
    cancel(this.searchTimer);

    if (this.dMenuInstance) {
      await this.dMenuInstance.close();
    }

    const draft = this.currentInputValue.trim();
    if (draft && isCompleteSegment(draft)) {
      this.tokens = [...this.tokens, ...splitFilterQuery(draft)];
      this.currentInputValue = "";
    }

    this.args.onChange(this.queryString, true);
  }

  @action
  syncFromInitialValue() {
    const incoming = splitFilterQuery(this.args.initialInputValue).join(" ");

    if (incoming !== this.queryString) {
      this.tokens = splitFilterQuery(incoming);
      this.currentInputValue = "";
    }
  }

  @action
  closeFilterMenu() {
    cancel(this.searchTimer);
    this.dMenuInstance?.close();
  }

  #submitTokens() {
    cancel(this.searchTimer);
    this.args.onChange(this.queryString, true);
  }

  <template>
    {{! eslint-disable ember/template-no-invalid-interactive }}
    <div
      class="topic-query-filter__input"
      {{didInsert this.storeContainerElement}}
      {{on "click" this.focusInputFromContainer}}
    >
      {{dIcon "filter" class="topic-query-filter__icon btn-flat"}}

      {{#each this.tokens as |raw index|}}
        <FilterNavigationToken
          @index={{index}}
          @onEdit={{fn this.editToken index}}
          @onEditorShow={{this.closeFilterMenu}}
          @onRemove={{fn this.removeToken index}}
          @onReplace={{fn this.replaceToken index}}
          @raw={{raw}}
          @tips={{@tips}}
          @tokens={{this.tokens}}
        />
      {{/each}}

      <input
        autocapitalize="none"
        autocomplete="off"
        autocorrect="off"
        class="topic-query-filter__filter-term"
        enterkeyhint="search"
        id="topic-query-filter-input"
        placeholder={{this.placeholder}}
        type="text"
        value={{this.currentInputValue}}
        {{on "keydown" this.handleKeydown}}
        {{on "input" (withEventValue this.updateInput)}}
        {{on "focus" this.openFilterMenu}}
        {{didInsert this.storeInputElement}}
        {{didUpdate this.syncFromInitialValue @initialInputValue}}
      />

      {{#if this.hasValue}}
        <DButton
          class="topic-query-filter__clear-btn btn-flat"
          @action={{this.clearInput}}
          @icon="xmark"
        />
      {{/if}}
    </div>
  </template>
}
