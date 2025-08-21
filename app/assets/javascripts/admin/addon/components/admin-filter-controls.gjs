import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { and, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DSelect from "discourse/components/d-select";
import FilterInput from "discourse/components/filter-input";

/**
 * admin filter controls component that support both client-side and server-side filtering
 *
 * client: provide searchableProps and filterFn in dropdownOptions
 * server: provide onTextFilterChange or onDropdownFilterChange callbacks
 *
 * @component AdminFilterControls
 * @param {Array} array - The dataset to display
 * @param {Array} [searchableProps] - Property names to search for client-side text filtering
 * @param {Array} [dropdownOptions] - Dropdown options. Format: [{value, label, filterFn?}]
 * @param {String} [inputPlaceholder] - Placeholder text for search input
 * @param {String} [defaultDropdown="all"] - Default dropdown value
 * @param {String} [noResultsMessage] - Message shown when no results found
 * @param {Boolean} [loading] - Whether data is loading (hides reset button during loading)
 * @param {Number} [minItemsForFilter] - Minimum items before showing filters (default: always show)
 * @param {Function} [onTextFilterChange] - Callback for text changes (enables server-side mode)
 * @param {Function} [onDropdownFilterChange] - Callback for dropdown changes (enables server-side mode)
 * @param {Function} [onResetFilters] - Callback for reset action (server-side mode)
 */

export default class AdminFilterControls extends Component {
  @tracked textFilter = "";
  @tracked dropdownFilter = "all";

  get array() {
    return Array.isArray(this.args.array) ? this.args.array : [];
  }

  get searchableProps() {
    return Array.isArray(this.args.searchableProps)
      ? this.args.searchableProps
      : [];
  }

  get dropdownOptions() {
    return Array.isArray(this.args.dropdownOptions)
      ? this.args.dropdownOptions
      : [];
  }

  get showDropdownFilter() {
    return this.dropdownOptions.length > 1;
  }

  get defaultDropdown() {
    return this.args.defaultDropdown || "all";
  }

  get showFilters() {
    return this.args.minItemsForFilter
      ? this.array.length >= this.args.minItemsForFilter
      : true;
  }

  get hasActiveFilters() {
    return (
      this.textFilter.length > 0 || this.dropdownFilter !== this.defaultDropdown
    );
  }

  get filteredData() {
    let filtered = [...this.array];

    // skip if we have external callbacks (server-side)
    const hasExternalCallbacks =
      this.args.onTextFilterChange || this.args.onDropdownFilterChange;
    if (hasExternalCallbacks) {
      return filtered;
    }

    if (this.textFilter.length > 0) {
      const term = this.textFilter.toLowerCase();
      filtered = filtered.filter((item) => {
        return this.searchableProps.some((key) => {
          const value = this.getNestedValue(item, key);
          return value && value.toString().toLowerCase().includes(term);
        });
      });
    }

    if (this.dropdownFilter !== this.defaultDropdown) {
      const selectedOption = this.dropdownOptions.find(
        (option) => option.value === this.dropdownFilter
      );
      if (selectedOption?.filterFn) {
        filtered = filtered.filter(selectedOption.filterFn);
      }
    }

    return filtered;
  }

  /**
   * get nested value
   * @param {Object} obj - The object to get value from
   * @param {String} path - The property path (e.g. "user.name")
   * @returns {*} The value at the path
   */
  getNestedValue(obj, path) {
    return path.split(".").reduce((current, key) => current?.[key], obj);
  }

  @action
  setupComponent() {
    this.dropdownFilter = this.defaultDropdown;
  }

  @action
  onTextFilterChange(event) {
    this.textFilter = event.target?.value || "";

    this.args.onTextFilterChange?.(event);
  }

  @action
  onDropdownFilterChange(value) {
    this.dropdownFilter = value;

    this.args.onDropdownFilterChange?.(value);
  }

  @action
  resetFilters() {
    this.textFilter = "";
    this.dropdownFilter = this.defaultDropdown;

    if (this.args.onResetFilters) {
      this.args.onResetFilters();
    }

    schedule("afterRender", () => {
      document.querySelector(".admin-filter-controls__input")?.focus();
    });
  }

  <template>
    {{#if this.showFilters}}
      <div class="admin-filter-controls" {{didInsert this.setupComponent}}>
        <FilterInput
          placeholder={{@inputPlaceholder}}
          @filterAction={{this.onTextFilterChange}}
          @value={{this.textFilter}}
          class="admin-filter-controls__input"
          @icons={{hash left="magnifying-glass"}}
        />

        {{#if this.showDropdownFilter}}
          <DSelect
            @value={{this.dropdownFilter}}
            @includeNone={{false}}
            @onChange={{this.onDropdownFilterChange}}
            class="admin-filter-controls__dropdown"
            as |select|
          >
            {{#each this.dropdownOptions as |option|}}
              <select.Option @value={{option.value}}>
                {{option.label}}
              </select.Option>
            {{/each}}
          </DSelect>
        {{/if}}

        {{yield to="actions"}}
      </div>
    {{/if}}

    {{#if this.filteredData.length}}
      {{yield this.filteredData to="content"}}
    {{else if this.showFilters}}
      {{#if (and this.hasActiveFilters (not @loading))}}
        <div class="admin-filter-controls__no-results">
          {{#if @noResultsMessage}}
            <p>{{@noResultsMessage}}</p>
          {{/if}}
          <DButton
            @icon="arrow-rotate-left"
            @label="admin.plugins.filters.reset"
            @action={{this.resetFilters}}
            class="btn-default admin-filter-controls__reset"
          />
        </div>
      {{/if}}
    {{else}}
      {{yield this.array to="content"}}
    {{/if}}
  </template>
}
