import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import DSelect from "discourse/components/d-select";
import FilterInput from "discourse/components/filter-input";
import concatClass from "discourse/helpers/concat-class";
import { isTesting } from "discourse/lib/environment";
import { and, not } from "discourse/truth-helpers";

/**
 * admin filter controls component that support both client-side and server-side filtering
 *
 * client: provide searchableProps and filterFn in dropdownOptions
 * server: provide onTextFilterChange or onDropdownFilterChange callbacks
 *
 * @component AdminFilterControls
 * @param {Array} array - The dataset to display
 * @param {Array} [searchableProps] - Property names to search for client-side text filtering, can be dot-separated
 *                                for nested properties (e.g. "user.name")
 * @param {Array|Object} [dropdownOptions] - Dropdown options. Format: [{value, label, filterFn?}]. Or, if you
 *                                   want multiple dropdowns, format is: { dropdown1: [...], dropdown2: [...] }
 * @param {String} [inputPlaceholder] - Placeholder text for search input
 * @param {String|Object} [defaultDropdownValue="all"] - Default dropdown value(s). For single dropdown: "all",
 *                                                       for multiple: { dropdown1: "all", dropdown2: "all" }
 * @param {String} [noResultsMessage] - Message shown when no results found
 * @param {Boolean} [loading] - Whether data is loading (hides reset button during loading)
 * @param {Number} [minItemsForFilter] - Minimum items before showing filters (default: always show)
 * @param {Function} [onTextFilterChange] - Callback for text changes (enables server-side mode)
 * @param {Function} [onDropdownFilterChange] - Callback for dropdown changes (enables server-side mode).
 *                                              For multiple dropdowns: receives (key, value)
 * @param {Function} [onResetFilters] - Callback for reset action (server-side mode)
 */

export default class AdminFilterControls extends Component {
  @tracked textFilter = "";
  @tracked dropdownFilter = "all";
  @tracked dropdownFilters = new TrackedObject();
  @tracked
  showFilterDropdowns = this.args.filterDropdownsExpanded ?? isTesting();

  constructor() {
    super(...arguments);

    if (this.hasMultipleDropdowns) {
      Object.keys(this.dropdownOptions).forEach((key) => {
        this.dropdownFilters[key] = this.defaultValue(key);
      });
    }
  }

  get array() {
    return Array.isArray(this.args.array) ? this.args.array : [];
  }

  get searchableProps() {
    return Array.isArray(this.args.searchableProps)
      ? this.args.searchableProps
      : [];
  }

  get hasMultipleDropdowns() {
    return (
      this.dropdownOptions &&
      !Array.isArray(this.dropdownOptions) &&
      typeof this.dropdownOptions === "object"
    );
  }

  get dropdownOptions() {
    if (!this.args.dropdownOptions) {
      return [];
    }
    return Array.isArray(this.args.dropdownOptions)
      ? this.args.dropdownOptions
      : this.args.dropdownOptions;
  }

  get showDropdownFilter() {
    return (
      this.dropdownOptions.length > 1 ||
      (this.hasMultipleDropdowns && this.showFilterDropdowns)
    );
  }

  get defaultDropdownValue() {
    return this.args.defaultDropdownValue || "all";
  }

  get showFilters() {
    return this.args.minItemsForFilter
      ? this.array.length >= this.args.minItemsForFilter
      : true;
  }

  get hasActiveFilters() {
    if (this.textFilter.length > 0) {
      return true;
    }

    if (this.hasMultipleDropdowns) {
      return Object.keys(this.dropdownFilters).some((key) => {
        return this.dropdownFilters[key] !== this.defaultValue(key);
      });
    }

    return this.dropdownFilter !== this.defaultDropdownValue;
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

    if (this.hasMultipleDropdowns) {
      Object.keys(this.dropdownFilters).forEach((key) => {
        const selectedValue = this.dropdownFilters[key];
        const options = this.dropdownOptions[key] || [];
        const selectedOption = options.find(
          (option) => option.value === selectedValue
        );
        if (selectedOption?.filterFn) {
          filtered = filtered.filter(selectedOption.filterFn);
        }
      });
    } else if (this.dropdownFilter !== this.defaultDropdownValue) {
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
   * Allows searchable props in the format user.name, this function gets the
   * nested value based on a dot-separated path.
   *
   * @param {Object} obj - The object to get value from
   * @param {String} path - The property path (e.g. "user.name")
   * @returns {*} The value at the path
   */
  getNestedValue(obj, path) {
    return path.split(".").reduce((current, key) => current?.[key], obj);
  }

  defaultValue(key) {
    const defaults =
      typeof this.defaultDropdownValue === "object"
        ? this.defaultDropdownValue
        : {};
    return defaults[key] || "all";
  }

  @action
  setupComponent() {
    if (this.hasMultipleDropdowns) {
      Object.keys(this.dropdownOptions).forEach((key) => {
        this.dropdownFilters[key] = this.defaultValue(key);
      });
    } else {
      this.dropdownFilter = this.defaultDropdownValue;
    }
  }

  @action
  onTextFilterChange(event) {
    this.textFilter = event.target?.value || "";

    this.args.onTextFilterChange?.(event);
  }

  @action
  onDropdownFilterChange(keyOrValue, value) {
    if (this.hasMultipleDropdowns) {
      this.dropdownFilters[keyOrValue] = value;
      this.args.onDropdownFilterChange?.(keyOrValue, value);
    } else {
      this.dropdownFilter = keyOrValue;
      this.args.onDropdownFilterChange?.(keyOrValue);
    }
  }

  @action
  resetFilters() {
    this.textFilter = "";

    if (this.hasMultipleDropdowns) {
      Object.keys(this.dropdownFilters).forEach((key) => {
        this.dropdownFilters[key] = this.defaultValue(key);
      });
    } else {
      this.dropdownFilter = this.defaultDropdownValue;
    }

    if (this.args.onResetFilters) {
      this.args.onResetFilters();
    }

    schedule("afterRender", () => {
      document.querySelector(".admin-filter-controls__input")?.focus();
    });
  }

  @action
  toggleFilters() {
    this.showFilterDropdowns = !this.showFilterDropdowns;
  }

  <template>
    {{yield to="aboveFilters"}}

    {{#if this.showFilters}}
      <div
        class={{concatClass
          "admin-filter-controls"
          (if this.hasMultipleDropdowns "--multiple-dropdowns")
        }}
        {{didInsert this.setupComponent}}
      >
        <div class="admin-filter-controls__inputs">
          <FilterInput
            placeholder={{@inputPlaceholder}}
            @filterAction={{this.onTextFilterChange}}
            @value={{this.textFilter}}
            class="admin-filter-controls__input"
            @icons={{hash left="magnifying-glass"}}
          />

          {{#if this.hasMultipleDropdowns}}
            <DButton
              class="btn-transparent admin-filter-controls__toggle-filters"
              @icon="filter"
              @title="toggle_filters"
              @action={{this.toggleFilters}}
            />
          {{/if}}
        </div>

        {{#if this.showDropdownFilter}}
          <div class="admin-filter-controls__dropdowns">
            {{#if this.hasMultipleDropdowns}}
              {{#each-in this.dropdownOptions as |key options|}}
                <DSelect
                  @value={{get this.dropdownFilters key}}
                  @includeNone={{false}}
                  @onChange={{fn this.onDropdownFilterChange key}}
                  class="admin-filter-controls__dropdown admin-filter-controls__dropdown--{{key}}"
                  data-dropdown-key={{key}}
                  as |select|
                >
                  {{#each options as |option|}}
                    <select.Option @value={{option.value}}>
                      {{option.label}}
                    </select.Option>
                  {{/each}}
                </DSelect>
              {{/each-in}}
            {{else}}
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
        {{/if}}

        {{yield to="actions"}}
      </div>
    {{/if}}

    {{yield to="aboveContent"}}

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
            @label="reset_filter"
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
