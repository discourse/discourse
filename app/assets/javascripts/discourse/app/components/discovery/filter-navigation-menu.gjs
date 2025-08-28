import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import categoryBadge from "discourse/helpers/category-badge";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import discourseDebounce from "discourse/lib/debounce";
import FilterSuggestions from "discourse/lib/filter-suggestions";
import { i18n } from "discourse-i18n";
import { VISIBILITY_OPTIMIZERS } from "float-kit/lib/constants";

const FilterNavigationMenuList = <template>
  {{#if @data.suggestions.length}}
    <DropdownMenu as |dropdown|>
      {{#each @data.suggestions as |item index|}}
        <dropdown.item
          class={{concatClass
            "filter-navigation__tip-item"
            (if (eq index @data.selectedIndex) "--selected")
          }}
          {{on "click" (fn @data.selectItem item)}}
        >
          {{#if item.category}}
            {{categoryBadge item.category allowUncategorized=true}}
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
    </DropdownMenu>
  {{/if}}
</template>;

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

  @tracked currentInputValue = this.args.initialInputValue || "";
  @tracked suggestions = [];
  @tracked activeFilter = null;

  lastSuggestionInput = "";
  suggestionRequestId = 0;

  trackedMenuListData = new TrackedObject({
    suggestions: [],
    selectedIndex: null,
    selectItem: this.selectItem,
  });

  searchTimer = null;
  inputElement = null;
  dMenuInstance = null;
  _selectedIndex = -1;

  get selectedIndex() {
    return this._selectedIndex;
  }

  set selectedIndex(value) {
    this._selectedIndex = value;
    this.trackedMenuListData.selectedIndex = value;
  }

  clearSelection() {
    this.selectedIndex = -1;
  }

  get nothingSelected() {
    return this.selectedIndex === -1;
  }

  @action
  storeInputElement(element) {
    this.inputElement = element;
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

      // Add space unless it's a filter that takes delimiters
      if (
        !newValue.endsWith(":") &&
        (!item.delimiters || item.delimiters.length < 2)
      ) {
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
  async updateInput(value, submitQuery = false) {
    value ??= "";
    this.currentInputValue = value;
    this.clearSelection();

    if (submitQuery) {
      // Cancel pending searches before submitting
      cancel(this.searchTimer);
      this.args.onChange(value, true);
    } else {
      this.args.onChange(value, false);
      await this.updateSuggestions();
    }
  }

  @action
  async clearInput() {
    await this.updateInput("", true);
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

    this.dMenuInstance = await this.menu.show(this.inputElement, {
      identifier: "filter-navigation-menu-list",
      component: FilterNavigationMenuList,
      data: this.trackedMenuListData,
      maxWidth: 2000,
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

    this.args.onChange(this.currentInputValue, true);
  }

  @action
  syncFromInitialValue() {
    if (this.currentInputValue !== this.args.initialInputValue) {
      this.currentInputValue = this.args.initialInputValue || "";
    }
  }

  <template>
    <div class="topic-query-filter__input">
      {{icon "filter" class="topic-query-filter__icon btn-flat"}}

      <input
        class="topic-query-filter__filter-term"
        value={{this.currentInputValue}}
        {{on "keydown" this.handleKeydown}}
        {{on "input" (withEventValue this.updateInput)}}
        {{on "focus" this.openFilterMenu}}
        {{didInsert this.storeInputElement}}
        autocapitalize="none"
        enterkeyhint="search"
        autocorrect="off"
        type="text"
        id="topic-query-filter-input"
        autocomplete="off"
        placeholder={{i18n "filter.placeholder"}}
        {{didUpdate this.syncFromInitialValue @initialInputValue}}
      />

      {{#if this.currentInputValue}}
        <DButton
          @icon="xmark"
          @action={{this.clearInput}}
          class="topic-query-filter__clear-btn btn-flat"
        />
      {{/if}}
    </div>
  </template>
}
