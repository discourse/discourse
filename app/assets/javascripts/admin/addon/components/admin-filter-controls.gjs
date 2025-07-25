import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { and, eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DSelect from "discourse/components/d-select";
import FilterInput from "discourse/components/filter-input";

/**
 *  admin filter controls component for filtering
 *
 * @component AdminFilterControls
 * @param {Array} array - The dataset to filter (must be an array)
 * @param {Array} searchableProps - Array of property names to search in for text filtering
 * @param {Array} dropdownOptions - Array of dropdown options [{value: "all", label: "All", filterFn: (item) => boolean}, ...]
 * @param {String} inputPlaceholder - Placeholder text for search input
 * @param {String} defaultDropdown - Default dropdown value (default: "all")
 * @param {String} noResultsMessage - Message to show when no results found (optional)
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

  get hasActiveFilters() {
    return (
      this.textFilter.length > 0 || this.dropdownFilter !== this.defaultDropdown
    );
  }

  get filteredData() {
    let filtered = [...this.array];

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
  }

  @action
  onDropdownFilterChange(value) {
    this.dropdownFilter = value;
  }

  @action
  resetFilters() {
    this.textFilter = "";
    this.dropdownFilter = this.defaultDropdown;

    schedule("afterRender", () => {
      document
        .querySelector(".admin-filter-controls .admin-filter__input")
        ?.focus();
    });
  }

  <template>
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

    </div>

    {{#if this.filteredData.length}}
      {{yield this.filteredData}}
    {{else}}

      {{#if (and this.hasActiveFilters (eq this.filteredData.length 0))}}
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
    {{/if}}
  </template>
}
