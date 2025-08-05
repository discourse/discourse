import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
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
import { resettableTracked } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";
import { VISIBILITY_OPTIMIZERS } from "float-kit/lib/constants";

const MAX_RESULTS = 20;

const FilterNavigationMenuList = <template>
  {{#if @data.filteredTips.length}}
    <DropdownMenu as |dropdown|>
      {{#each @data.filteredTips as |item index|}}
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
 * This component provides an input field and parsing logic for filter
 * queries. Every time the input changes, we recalculate the list of
 * filter tips that match the current input value.
 *
 * We start from an initial list of tips provided by the server
 * (see TopicsFilter.option_info) which are reduced to a list of "high priority/top-level"
 * filters if there is no user input value.
 *
 * Once the user starts typing, we parse the input value to determine
 * the last word and its prefix (if any). If the last word contains a colon,
 * we treat it as a filter name and look for matching tips via the FilterSuggestions service.
 * For example after "category:" is typed we show a list of categories the user
 * has access to.
 *
 * Each filter tip can have prefixes (like "-", "=", and "-=") that modify the filter behavior,
 * as well as delimiters (like ",") that allow for multiple values.
 */
export default class FilterNavigationMenu extends Component {
  @service menu;
  @service site;

  @resettableTracked currentInputValue = this.args.initialInputValue || "";

  filterSuggessionResults = [];
  activeFilter = null;
  trackedMenuListData = new TrackedObject({
    filteredTips: this.filteredTips,
    selectedIndex: null,
    selectItem: this.selectItem,
  });

  @tracked _selectedIndex = -1;

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

  get filteredTips() {
    if (!this.args.tips) {
      return [];
    }

    const words = this.currentInputValue.split(/\s+/);
    const lastWord = words.at(-1).toLowerCase();

    // If we're already filtering by a type like "category:" that has suggestions,
    // we want to only show those suggestions.
    if (this.activeFilter && this.filterSuggessionResults.length > 0) {
      return this.filterSuggessionResults;
    }

    // We are filtering by a type here like "category:", "tag:", etc.
    // since the last word contains a colon.
    const colonIndex = lastWord.indexOf(":");
    const prefix = this.#extractPrefix(lastWord) || "";
    if (colonIndex > 0) {
      const filterName = lastWord.substring(prefix.length).split(":")[0];
      const valueText = lastWord.substring(colonIndex + 1);
      const tip = this.args.tips.find((t) => t.name === filterName + ":");

      if (tip?.type && valueText !== undefined) {
        this.handleFilterSuggestionSearch(filterName, valueText, tip, prefix);
        return this.filterSuggessionResults.length > 0
          ? this.filterSuggessionResults
          : [];
      }
    }

    // Get a list of the "top-level" filters that have a priority of 1,
    // such as category:, created-after:, tags:, etc.
    if (!this.currentInputValue || lastWord === "") {
      return this.args.tips
        .filter((tip) => tip.priority)
        .sort((a, b) => (b.priority || 0) - (a.priority || 0))
        .sort((a, b) => {
          const aName = a.name.toLowerCase();
          const bName = b.name.toLowerCase();
          return aName.localeCompare(bName);
        })
        .slice(0, MAX_RESULTS);
    }

    return this.filterAllTips(lastWord, prefix);
  }

  /**
   * Filters all available tips based on a search term from the user input
   *
   * This method searches through the complete list of filter tips and finds matches based on:
   * 1. Direct name matches with the search term
   * 2. Matches against tip aliases
   * 3. Support for prefixed tips (like "-", "=", "-=")
   *
   * Results are sorted to prioritize exact matches first and are limited to MAX_RESULTS
   *
   * @param {string} lastWord - The last word in the input string (what user is currently typing)
   * @param {string} prefix - Any detected prefix modifier like "-", "=", or "-="
   * @returns {Array} - Array of matching tip objects for display in the menu
   */
  filterAllTips(lastWord, prefix) {
    const tips = [];
    this.args.tips.forEach((tip) => {
      if (tips.length >= MAX_RESULTS) {
        return;
      }
      const tipName = tip.name;
      const searchTerm = lastWord.substring(prefix.length);

      if (searchTerm.endsWith(":") && tipName === searchTerm) {
        return;
      }

      const prefixMatch =
        searchTerm === "" &&
        prefix &&
        tipName.prefixes &&
        tipName.prefixes.find((p) => p.name === prefix);

      if (prefixMatch || tipName.indexOf(searchTerm) > -1) {
        this.#pushPrefixTips(tip, tips, null, prefix);
        if (!prefix) {
          tips.push(tip);
        }
      } else if (tip.alias && tip.alias.indexOf(searchTerm) > -1) {
        this.#pushPrefixTips(tip, tips, tip.alias, prefix);
        tips.push({ ...tip, name: tip.alias });
      }
    });

    return tips.sort((a, b) => {
      const aName = a.name.toLowerCase();
      const bName = b.name.toLowerCase();
      const aStartsWith = aName.startsWith(lastWord.toLowerCase());
      const bStartsWith = bName.startsWith(lastWord.toLowerCase());
      if (aStartsWith && !bStartsWith) {
        return -1;
      }
      if (!aStartsWith && bStartsWith) {
        return 1;
      }
      if (aStartsWith && bStartsWith && aName.length !== bName.length) {
        return aName.length - bName.length;
      }
      return aName.localeCompare(bName);
    });
  }

  /**
   * Updates the component state based on the current input value
   *
   * Unlike the filteredTips getter which just returns the current suggestions,
   * this method actively parses the input and updates internal state:
   *
   * - Resets selection state
   * - Sets or clears the activeFilter based on detected filter types
   * - Triggers filter-specific suggestion searches when appropriate
   * - Updates the reactive state to ensure UI reflects current filter state
   *
   * This method should be called after actions that modify the input value
   * to ensure the component's internal state is synchronized with the input.
   */
  updateResults() {
    this.clearSelection();

    const words = this.currentInputValue.split(/\s+/);
    const lastWord = words.at(-1);
    const colonIndex = lastWord.indexOf(":");

    if (colonIndex > 0) {
      const prefix = this.#extractPrefix(lastWord);
      const filterName = lastWord.substring(
        prefix.length,
        colonIndex + prefix.length
      );
      const valueText = lastWord.substring(colonIndex + 1);

      const tip = this.args.tips.find((t) => {
        const tipFilterName = t.name.replace(/^[-=]/, "").split(":")[0];
        return tipFilterName === filterName && t.type;
      });

      if (tip?.type) {
        this.activeFilter = filterName;
        this.handleFilterSuggestionSearch(filterName, valueText, tip, prefix);
      } else {
        this.activeFilter = null;
        this.filterSuggessionResults = [];
      }
    } else {
      this.activeFilter = null;
      this.filterSuggessionResults = [];
    }

    this.trackedMenuListData.filteredTips = this.filteredTips;
  }

  #pushPrefixTips(tip, tips, alias = null, currentPrefix = null) {
    if (tip.prefixes && tip.prefixes.length > 0) {
      tip.prefixes.forEach((prefix) => {
        if (currentPrefix && !prefix.name.startsWith(currentPrefix)) {
          return;
        }
        tips.push({
          ...tip,
          name: `${prefix.name}${alias || tip.name}`,
          description: prefix.description || tip.description,
          isSuggestion: true,
        });
      });
    }
  }

  #extractPrefix(word) {
    const match = word.match(/^(-=|=-|-|=)/);
    return match ? match[0] : "";
  }

  @action
  storeInputElement(element) {
    this.inputElement = element;
  }

  @action
  handleFilterSuggestionSearch(filterName, valueText, tip, prefix = "") {
    this.activeFilter = filterName;
    this.searchTimer = discourseDebounce(
      this,
      this.#performFilterSuggestionSearch,
      filterName,
      valueText,
      tip,
      prefix,
      300
    );
  }

  /**
   * Handles selection of a filter tip item from the dropdown menu.
   * See TopicsFilter.option_info for the structure of the item
   * on the server.
   *
   * @param {Object} item - A filter tip object from the initial list or from the filter suggestions
   * @param {string} item.name - The name of the filter (e.g. "category:", "tag:")
   * @param {string} [item.alias] - Alternative name for the filter (e.g. "categories:")
   * @param {string} [item.description] - Human-readable description of the filter
   * @param {number} [item.priority] - Priority value for sorting (higher appears first)
   * @param {string} [item.type] - Type of filter for suggestions (category, tag, username, date, number)
   * @param {Array<Object>} [item.delimiters] - Delimiter options for multiple values
   * @param {Array<Object>} [item.prefixes] - Prefix modifiers for this filter (-, =, -=)
   * @param {boolean} [item.isSuggestion] - Whether this is a suggestion for a specific filter value
   */
  @action
  selectItem(item) {
    // Split up the string from the text input into words.
    const words = this.currentInputValue.split(/\s+/);

    // If we are selecting an item that was suggested based on the initial
    // word selected (e.g. after picking a "category:" the user selects a
    // category from the list), we replace the last word with the selected item.
    if (item.isSuggestion) {
      words[words.length - 1] = item.name;
      let updatedInputValue = words.join(" ");
      if (
        !updatedInputValue.endsWith(":") &&
        (!item.delimiters || item.delimiters.length < 2)
      ) {
        updatedInputValue += " ";
      }
      this.updateInput(updatedInputValue);
    } else {
      // Otherwise if the user is selecting a filter from the initial tips,
      // we add a colon to the end of it as needed, and fire off the
      // suggestion search based on the filter type.
      const lastWord = words.at(-1);
      const prefix = this.#extractPrefix(lastWord);
      const supportsPrefix = item.prefixes && item.prefixes.length > 0;
      const filterName =
        supportsPrefix && prefix ? `${prefix}${item.name}` : item.name;

      words[words.length - 1] = filterName;
      if (!filterName.endsWith(":") && !item.delimiters?.length) {
        words[words.length - 1] += " ";
      }

      const updatedInputValue = words.join(" ");
      this.updateInput(updatedInputValue);

      const baseFilterName = item.name.replace(/^[-=]/, "").split(":")[0];
      if (item.type) {
        this.activeFilter = baseFilterName;
        this.handleFilterSuggestionSearch(baseFilterName, "", item, prefix);
      }
    }

    this.clearSelection();
    this.inputElement.focus();
  }

  @action
  updateInput(updatedInputValue, refreshQuery = false) {
    this.currentInputValue = updatedInputValue;
    this.args.onChange(updatedInputValue, refreshQuery);
    this.trackedMenuListData.filteredTips = this.filteredTips;
    this.updateResults();
  }

  @action
  clearInput() {
    this.updateInput("", true);
    this.inputElement.focus();
  }

  @action
  async openFilterMenu() {
    if (this.dMenuInstance) {
      this.dMenuInstance.show();
      return;
    }

    this.dMenuInstance = await this.menu.show(this.inputElement, {
      identifier: "filter-navigation-menu-list",
      component: FilterNavigationMenuList,
      data: this.trackedMenuListData,
      maxWidth: 2000,
      matchTriggerWidth: true,
      visibilityOptimizer: VISIBILITY_OPTIMIZERS.AUTO_PLACEMENT,
    });
  }

  @action
  handleKeydown(event) {
    if (
      this.filteredTips.length === 0 &&
      ["ArrowDown", "ArrowUp", "Tab"].includes(event.key)
    ) {
      return;
    }

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        this.selectedIndex = this.nothingSelected
          ? 0
          : (this.selectedIndex + 1) % this.filteredTips.length;
        break;
      case "ArrowUp":
        event.preventDefault();
        this.selectedIndex = this.nothingSelected
          ? this.filteredTips.length - 1
          : (this.selectedIndex - 1 + this.filteredTips.length) %
            this.filteredTips.length;
        break;
      case "Tab":
        event.preventDefault();
        event.stopPropagation();
        this.selectItem(
          this.filteredTips[this.nothingSelected ? 0 : this.selectedIndex]
        );
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
          this.selectItem(this.filteredTips[this.selectedIndex]);
        } else {
          cancel(this.searchTimer);

          if (!this.dMenuInstance) {
            this.args.onChange(this.currentInputValue, true);
          } else {
            this.dMenuInstance.close().then(() => {
              this.args.onChange(this.currentInputValue, true);
            });
          }
        }
        break;
      case "Escape":
        this.dMenuInstance?.close();
        break;
    }
  }

  async #performFilterSuggestionSearch(filterName, valueText, tip, prefix) {
    let lastTerm = valueText;
    let results = [];
    let prevTerms = "";
    let splitTerms;

    if (tip.delimiters) {
      const delimiters = tip.delimiters.map((s) => s.name);
      splitTerms = lastTerm.split(new RegExp(`[${delimiters.join("")}]`));
      lastTerm = splitTerms[splitTerms.length - 1];
      prevTerms =
        lastTerm === "" ? valueText : valueText.slice(0, -lastTerm.length);
    }

    lastTerm = (lastTerm || "").toLowerCase().trim();

    results = await FilterSuggestions.getFilterSuggestionsByType(
      tip,
      prefix,
      filterName,
      prevTerms,
      lastTerm,
      { site: this.site }
    );

    if (tip.delimiters) {
      let lastMatches = false;

      results.forEach((result) => (result.delimiters = tip.delimiters));

      results = results.filter((result) => {
        lastMatches ||= lastTerm === result.term;
        return !splitTerms.includes(result.term);
      });

      if (lastMatches) {
        tip.delimiters.forEach((delimiter) => {
          results.push({
            name: `${prefix}${filterName}:${prevTerms}${lastTerm}${delimiter.name}`,
            description: delimiter.description,
            isSuggestion: true,
            delimiters: tip.delimiters,
          });
        });
      }
    }

    this.filterSuggessionResults = results || [];
    this.trackedMenuListData.filteredTips = this.filteredTips;
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
        type="text"
        id="topic-query-filter-input"
        autocomplete="off"
        placeholder={{i18n "filter.placeholder"}}
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
