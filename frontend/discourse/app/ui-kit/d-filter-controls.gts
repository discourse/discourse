import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import type { TOC } from "@ember/component/template-only";
import { concat, fn, get, hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { trackedObject } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import type RouterService from "@ember/routing/router-service";
import { cancel, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY, isTesting } from "discourse/lib/environment";
import { resettableTracked } from "discourse/lib/tracked-tools";
import DiscourseURL, {
  applyQueryParams,
  searchParamsFromPath,
} from "discourse/lib/url";
import type { CapabilitiesService } from "discourse/services/capabilities";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

/** The site settings this component reads. */
type SiteSettings = {
  enable_new_select_controls: boolean;
};

/** An option of a filter dropdown. */
export interface DFilterControlsDropdownOption<T = unknown> {
  /** The value of the option. */
  value: string;

  /** The label of the option. */
  label: string;

  /** Keeps the items that match the option, for client-side filtering. */
  filterFn?: (item: T) => boolean;
}

/** An option of the sort menu. */
export interface DFilterControlsSortOption<T = unknown> {
  /** The value of the option. */
  value: string;

  /** The label of the option. */
  label: string;

  /** Orders the items, for client-side sorting. Omit it to sort on the server. */
  compareFn?: (a: T, b: T) => number;
}

/** The options of one dropdown, or of several dropdowns keyed by name. */
export type DFilterControlsDropdownOptions<T = unknown> =
  | DFilterControlsDropdownOption<T>[]
  | DropdownOptionsByKey<T>;

type DropdownOptionsByKey<T> = Record<
  string,
  DFilterControlsDropdownOption<T>[]
>;

interface ResetButtonSignature {
  Args: {
    action: () => void;
    disabled?: boolean;
    label?: string;
  };
}

interface SortMenuSignature {
  Args: {
    label?: string;
    onChange: (close: () => void, value: string) => void;
    options: Pick<DFilterControlsSortOption, "value" | "label">[];
    showLabel?: boolean;
    value?: string;
  };
}

interface DFilterControlsSignature<T> {
  Args: {
    /** The dataset to display. */
    array?: T[];

    /**
     * Property names to search for client-side text filtering. They can be dot-separated
     * for nested properties, such as `user.name`.
     */
    searchableProps?: string[];

    /** The dropdown options. Key them by name for several dropdowns. */
    dropdownOptions?: DFilterControlsDropdownOptions<T>;

    /**
     * Sort menu options. The menu shows with two or more options. Reset leaves the sort in
     * place, as it isn't a filter.
     */
    sortOptions?: DFilterControlsSortOption<T>[];

    /** The default sort value. Defaults to the first option. */
    defaultSort?: string;

    /** The query param that holds a non-default sort. */
    sortQueryParam?: string;

    /** Called with the new sort value. */
    onSortChange?: (value: string) => void;

    /** Placeholder text for the search input. */
    inputPlaceholder?: string;

    /** The default dropdown value, or values keyed by dropdown. Defaults to `all`. */
    defaultDropdownValue?: string | Record<string, string>;

    /** The current dropdown value, or values keyed by dropdown. */
    dropdownValue?: string | Record<string, string>;

    /** The query param that holds the dropdown value. */
    dropdownFilterQueryParam?: string;

    /** The query params that hold the dropdown values, keyed by dropdown. */
    dropdownFilterQueryParams?: Record<string, string>;

    /** The query param that holds the text filter. */
    textFilterQueryParam?: string;

    /**
     * Whether to render the dropdown drawer toggle. Defaults to true for multiple
     * dropdowns or when forced.
     */
    showDropdownFilterToggle?: boolean;

    /** Whether to place a single dropdown behind the filter toggle. */
    forceShowDropdownFilterToggle?: boolean;

    /** Whether the dropdown drawer starts open. */
    filterDropdownsExpanded?: boolean;

    /** The message shown when no results are found. */
    noResultsMessage?: string;

    /** Whether to show the built-in no-results state. Defaults to `true`. */
    showNoResults?: boolean;

    /** Whether to show the text filter input. Defaults to `true`. */
    showTextFilter?: boolean;

    /** Whether to show the reset filters button. Defaults to `true`. */
    showResetButton?: boolean;

    /** Whether data is loading. It hides the no-results state. */
    loading?: boolean;

    /** The minimum number of items before the filters show. */
    minItemsForFilter?: number;

    /** Called on text changes. It enables server-side filtering. */
    onTextFilterChange?: (event: Event) => void;

    /**
     * Called on dropdown changes. It enables server-side filtering. With several
     * dropdowns, it receives the dropdown key and the value.
     */
    onDropdownFilterChange?: (keyOrValue: string, value?: string) => void;

    /** Called on dropdown selection changes, with the same arguments. */
    onDropdownChange?: (keyOrValue: string, value?: string) => void;

    /** Called on reset, for server-side filtering. */
    onResetFilters?: () => void | Promise<void>;

    /** Called with the new expanded state when the dropdown drawer opens or closes. */
    onFilterDropdownsToggle?: (expanded: boolean) => void;

    /** The label of the filter drawer button, already translated. */
    toggleLabel?: string;

    /** Whether filters rendered in the `additionalFilters` block are active. */
    additionalFiltersActive?: boolean;

    /** The initial value of the text filter. */
    initialTextFilter?: string;

    /**
     * Whether to show the `customEmptyState` block when the array is empty and
     * `@minItemsForFilter` hides the filters.
     */
    showCustomEmptyState?: boolean;
  };

  Blocks: {
    /** Content above the filters. */
    aboveFilters: [];

    /** Controls placed beside the search input, outside the drawer. */
    inlineFilters: [];

    /** Filters rendered with the dropdowns, sharing the drawer. */
    additionalFilters: [];

    /** Actions after the filters. */
    actions: [];

    /** Content between the filters and the results. */
    aboveContent: [];

    /** The results. */
    content: [items: T[]];

    /** The empty state, with `@showCustomEmptyState`. */
    customEmptyState: [];
  };
}

const ResetButton: TOC<ResetButtonSignature> = <template>
  <DButton
    class="btn-default d-filter-controls__reset"
    @action={{@action}}
    @ariaLabel="filter_controls.reset"
    @disabled={{@disabled}}
    @icon="arrow-rotate-left"
    @label={{@label}}
    @title="filter_controls.reset"
  />
</template>;

const SortMenu: TOC<SortMenuSignature> = <template>
  <DMenu
    @ariaLabel={{i18n "filter_controls.sort_trigger_label" sort=@label}}
    @icon="arrow-down-wide-short"
    @identifier="d-filter-controls-sort"
    @label={{if @showLabel @label}}
    @modalForMobile={{true}}
    @placement="bottom-end"
    @title={{i18n "filter_controls.sort_trigger_label" sort=@label}}
    @triggerClass="btn-default d-filter-controls__sort-trigger"
  >
    <:content as |menu|>
      <DDropdownMenu as |dropdown|>
        <dropdown.subheader>
          {{i18n "filter_controls.sort_label"}}
        </dropdown.subheader>
        {{#each @options as |option|}}
          <dropdown.item>
            <DButton
              aria-current={{if (eq option.value @value) "true"}}
              class="btn-transparent d-filter-controls__sort-option"
              data-sort={{option.value}}
              @action={{fn @onChange menu.close option.value}}
              @suffixIcon={{if (eq option.value @value) "check"}}
              @translatedLabel={{option.label}}
            />
          </dropdown.item>
        {{/each}}
      </DDropdownMenu>
    </:content>
  </DMenu>
</template>;

/**
 * filter controls component that support both client-side and server-side filtering
 *
 * client: provide searchableProps and filterFn in dropdownOptions
 * server: provide onTextFilterChange or onDropdownFilterChange callbacks
 *
 * The inlineFilters block places controls beside the search input, outside the drawer.
 *
 */

export default class DFilterControls<T = unknown> extends Component<
  DFilterControlsSignature<T>
> {
  @service declare capabilities: CapabilitiesService;
  @service declare router: RouterService;
  @service declare siteSettings: SiteSettings;

  @tracked dropdownFilter = "all";
  @tracked
  showFilterDropdowns = this.args.filterDropdownsExpanded ?? isTesting();
  @resettableTracked sort = this.initialSortValue;
  @resettableTracked textFilter = this.initialTextFilterValue;

  dropdownFilters = trackedObject<Record<string, string>>();
  #searchSeed = tracked(this.#linkedSearch);
  #searchDebounce: ReturnType<typeof discourseDebounce> | undefined;

  constructor(owner: Owner, args: DFilterControlsSignature<T>["Args"]) {
    super(owner, args);

    this.applyDropdownValues();

    if (this.#hasUrlOwnedFilters) {
      // keep URL-owned filters in sync across real transitions (e.g. a
      // same-route link with different params); our own replaceState writes
      // don't fire this event, so user selections are never reverted
      this.router.on("routeDidChange", this.applyFiltersFromRoute);
    }
  }

  willDestroy() {
    super.willDestroy();
    cancel(this.#searchDebounce);
    if (this.#hasUrlOwnedFilters) {
      this.router.off("routeDidChange", this.applyFiltersFromRoute);
    }
  }

  get initialTextFilterValue(): string {
    if (!this.showTextFilter) {
      return "";
    }

    const seed = this.showFilters ? this.#searchSeed.value : null;
    return seed ?? (this.args.initialTextFilter?.replace(/,\s*/g, ", ") || "");
  }

  get initialSortValue() {
    const fromUrl =
      this.args.sortQueryParam && this.showFilters
        ? this.#validatedUrlValue(
            this.currentSearchParams,
            this.args.sortQueryParam,
            this.sortOptions
          )
        : null;

    return fromUrl ?? this.defaultSort;
  }

  get currentSearchParams(): URLSearchParams {
    // router.currentURL, unlike window.location, is also correct under the
    // test environment's mock location
    return searchParamsFromPath(this.router.currentURL);
  }

  get hasUrlOwnedDropdowns() {
    return (
      (this.args.dropdownFilterQueryParam ||
        this.args.dropdownFilterQueryParams) &&
      !("dropdownValue" in this.args)
    );
  }

  get #linkedSearch(): string | null {
    const param = this.args.textFilterQueryParam;
    return param ? this.currentSearchParams.get(param) : null;
  }

  get #hasUrlOwnedFilters() {
    return this.args.textFilterQueryParam || this.hasUrlOwnedDropdowns;
  }

  get array(): T[] {
    return Array.isArray(this.args.array) ? this.args.array : [];
  }

  get searchableProps() {
    return Array.isArray(this.args.searchableProps)
      ? this.args.searchableProps
      : [];
  }

  get hasMultipleDropdowns() {
    return (
      !Array.isArray(this.dropdownOptions) &&
      typeof this.dropdownOptions === "object"
    );
  }

  get dropdownOptions(): DFilterControlsDropdownOptions<T> {
    return this.args.dropdownOptions || [];
  }

  /**
   * The options of the single dropdown.
   *
   * @returns The options, or an empty list when there are several dropdowns.
   */
  get dropdownOptionList(): DFilterControlsDropdownOption<T>[] {
    const options = this.dropdownOptions;
    return Array.isArray(options) ? options : [];
  }

  /**
   * The options of each dropdown, keyed by name.
   *
   * @returns The options by name, or an empty object when there is one dropdown.
   */
  get dropdownOptionsByKey(): DropdownOptionsByKey<T> {
    const options = this.dropdownOptions;
    return Array.isArray(options) ? {} : options;
  }

  get sortOptions() {
    return this.args.sortOptions ?? [];
  }

  get defaultSort() {
    return this.args.defaultSort ?? this.sortOptions[0]?.value;
  }

  get showSort() {
    return this.sortOptions.length > 1;
  }

  get sortLabel() {
    return this.sortOptions.find((option) => option.value === this.sort)?.label;
  }

  get showDropdownFilterToggle() {
    return (
      this.args.showDropdownFilterToggle ??
      (this.hasMultipleDropdowns || this.args.forceShowDropdownFilterToggle)
    );
  }

  get showDropdownFilter() {
    return (
      (this.dropdownOptionList.length > 1 &&
        !this.args.forceShowDropdownFilterToggle) ||
      (this.hasMultipleDropdowns && this.showFilterDropdowns) ||
      (this.args.forceShowDropdownFilterToggle && this.showFilterDropdowns)
    );
  }

  // additional filters share the dropdown row, so they follow the drawer's
  // state; with no drawer to hide behind they render on their own
  get showStandaloneAdditionalFilters() {
    return !this.showDropdownFilterToggle;
  }

  get showTextFilter() {
    return this.args.showTextFilter ?? true;
  }

  get showResetButton() {
    return this.args.showResetButton ?? true;
  }

  get defaultDropdownValue() {
    return this.args.defaultDropdownValue || "all";
  }

  get dropdownValue() {
    return this.args.dropdownValue || this.defaultDropdownValue;
  }

  get showFilters() {
    return this.args.minItemsForFilter
      ? this.array.length >= this.args.minItemsForFilter
      : true;
  }

  get showNoResults() {
    return this.args.showNoResults ?? true;
  }

  get hasActiveFilters() {
    if (this.args.additionalFiltersActive) {
      return true;
    }

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
      return this.#sorted(filtered);
    }

    if (this.textFilter.length > 0) {
      const terms = this.textFilter
        .split(",")
        .map((t) => t.trim().toLowerCase())
        .filter(Boolean);
      filtered = filtered.filter((item) =>
        terms.some((term) =>
          this.searchableProps.some((key) => {
            const value = this.getNestedValue(item, key);
            return value && value.toString().toLowerCase().includes(term);
          })
        )
      );
    }

    if (this.hasMultipleDropdowns) {
      Object.keys(this.dropdownFilters).forEach((key) => {
        const selectedValue = this.dropdownFilters[key];
        const options = this.dropdownOptionsByKey[key] || [];
        const selectedOption = options.find(
          (option) => option.value === selectedValue
        );
        if (selectedOption?.filterFn) {
          filtered = filtered.filter(selectedOption.filterFn);
        }
      });
    } else if (this.dropdownFilter !== this.defaultDropdownValue) {
      const selectedOption = this.dropdownOptionList.find(
        (option) => option.value === this.dropdownFilter
      );
      if (selectedOption?.filterFn) {
        filtered = filtered.filter(selectedOption.filterFn);
      }
    }

    return this.#sorted(filtered);
  }

  get singleDropdownLabel() {
    return this.dropdownOptionList.find(
      (option) => option.value === this.defaultDropdownValue
    )?.label;
  }

  /**
   * Allows searchable props in the format user.name, this function gets the
   * nested value based on a dot-separated path.
   *
   * @param obj - The object to get value from
   * @param path - The property path (e.g. "user.name")
   * @returns The value at the path
   */
  getNestedValue(obj: unknown, path: string): unknown {
    return path
      .split(".")
      .reduce<unknown>(
        (current, key) =>
          (current as Record<string, unknown> | null | undefined)?.[key],
        obj
      );
  }

  // @action so it stays bound to `this` when invoked from the template
  @action
  defaultValue(key: string): string {
    const defaults: Record<string, string> =
      typeof this.defaultDropdownValue === "object"
        ? this.defaultDropdownValue
        : {};
    return defaults[key] || "all";
  }

  @action
  dropdownLabel(key: string): string | undefined {
    const options = this.dropdownOptionsByKey[key] || [];
    return options.find((option) => option.value === this.defaultValue(key))
      ?.label;
  }

  @action
  applyFiltersFromRoute() {
    cancel(this.#searchDebounce);
    this.#searchDebounce = undefined;
    this.#searchSeed.value = this.#linkedSearch;
    if (this.args.textFilterQueryParam) {
      this.textFilter = this.initialTextFilterValue;
    }
    this.applyDropdownsFromUrl();
  }

  @action
  applyDropdownsFromUrl() {
    if (!this.showFilters || !this.hasUrlOwnedDropdowns) {
      return;
    }

    const params = this.currentSearchParams;

    if (this.hasMultipleDropdowns) {
      for (const [key, paramName] of Object.entries(
        this.args.dropdownFilterQueryParams ?? {}
      )) {
        const defaultValue = this.defaultValue(key);
        const value =
          this.#validatedUrlValue(
            params,
            paramName,
            this.dropdownOptionsByKey[key] ?? []
          ) ?? defaultValue;

        this.dropdownFilters[key] = value;
        this.showFilterDropdowns ||= value !== defaultValue;
      }
    } else if (this.args.dropdownFilterQueryParam) {
      this.dropdownFilter =
        this.#validatedUrlValue(
          params,
          this.args.dropdownFilterQueryParam,
          this.dropdownOptionList
        ) ?? (this.defaultDropdownValue as string);
    }
  }

  dropdownValueFor(key: string): string {
    const values: Record<string, string> =
      typeof this.dropdownValue === "object" ? this.dropdownValue : {};
    return values[key] || this.defaultValue(key);
  }

  @action
  applyDropdownValues() {
    if (this.hasMultipleDropdowns) {
      Object.keys(this.dropdownOptions).forEach((key) => {
        this.dropdownFilters[key] = this.dropdownValueFor(key);
      });
    } else {
      this.dropdownFilter = this.dropdownValue as string;
    }
  }

  updateQueryParams(updates: Record<string, string | null | undefined>) {
    // no currentURL means the router isn't live (e.g. rendering tests)
    if (!this.showFilters || !this.router.currentURL) {
      return;
    }

    const searchParam = this.args.textFilterQueryParam;
    if (searchParam && this.#searchDebounce && !(searchParam in updates)) {
      cancel(this.#searchDebounce);
      updates = { [searchParam]: this.textFilter, ...updates };
    }

    DiscourseURL.replaceState(
      applyQueryParams(this.router.currentURL, updates)
    );
  }

  @action
  onTextFilterChange(event: Event) {
    this.textFilter = (event.target as HTMLInputElement | null)?.value || "";

    this.#scheduleSearchSync();

    this.args.onTextFilterChange?.(event);
  }

  @action
  onSingleDropdownChange(value: string | null) {
    // Every option has a value, so the select never reports none.
    if (value === null) {
      return;
    }

    this.dropdownFilter = value;
    this.#updateDropdownQueryParam(
      this.args.dropdownFilterQueryParam,
      value,
      this.defaultDropdownValue
    );
    this.args.onDropdownFilterChange?.(value);
    this.args.onDropdownChange?.(value);
  }

  @action
  onKeyedDropdownChange(key: string, value: string | null) {
    // Every option has a value, so the select never reports none.
    if (value === null) {
      return;
    }

    this.dropdownFilters[key] = value;
    this.#updateDropdownQueryParam(
      this.args.dropdownFilterQueryParams?.[key],
      value,
      this.defaultValue(key)
    );
    this.args.onDropdownFilterChange?.(key, value);
    this.args.onDropdownChange?.(key, value);
  }

  /** Takes the value as DSelect reports it; sort options' values are strings. */
  @action
  changeSort(value: unknown) {
    const sort = value as string;
    this.sort = sort;

    if (this.args.sortQueryParam) {
      this.updateQueryParams({
        [this.args.sortQueryParam]: sort === this.defaultSort ? null : sort,
      });
    }

    this.args.onSortChange?.(sort);
  }

  @action
  onSortChange(close: () => void, value: string) {
    this.changeSort(value);
    close();
  }

  @action
  async resetFilters() {
    this.textFilter = "";

    if (this.hasMultipleDropdowns) {
      Object.keys(this.dropdownFilters).forEach((key) => {
        const defaultValue = this.defaultValue(key);
        this.dropdownFilters[key] = defaultValue;
        this.args.onDropdownChange?.(key, defaultValue);
      });
    } else {
      this.dropdownFilter = this.defaultDropdownValue as string;
      this.args.onDropdownChange?.(this.defaultDropdownValue as string);
    }

    const queryParams = [
      this.args.textFilterQueryParam,
      this.args.dropdownFilterQueryParam,
      ...Object.values(this.args.dropdownFilterQueryParams ?? {}),
    ].filter((name): name is string => Boolean(name));
    if (queryParams.length) {
      const updates = Object.fromEntries(
        queryParams.map((name) => [name, null])
      );
      this.updateQueryParams(updates);
      // a search write still in flight can land after this one
      if (this.#searchDebounce) {
        this.#scheduleSearchSync(updates);
      }
    }

    await this.args.onResetFilters?.();

    schedule("afterRender", () => {
      (
        document.querySelector<HTMLElement>(".d-filter-controls__input") ||
        document.querySelector<HTMLElement>(
          ".d-filter-controls__toggle-filters"
        ) ||
        document.querySelector<HTMLElement>(".d-filter-controls__dropdown")
      )?.focus();
    });
  }

  @action
  toggleFilters() {
    this.showFilterDropdowns = !this.showFilterDropdowns;
    this.args.onFilterDropdownsToggle?.(this.showFilterDropdowns);
  }

  #scheduleSearchSync(updates = {}) {
    if (this.args.textFilterQueryParam) {
      this.#searchSeed.value ??= this.initialTextFilterValue;
      this.#searchDebounce = discourseDebounce(
        this,
        this.updateQueryParams,
        updates,
        INPUT_DELAY
      );
    }
  }

  #updateDropdownQueryParam(
    paramName: string | undefined,
    value: string,
    defaultValue: string | Record<string, string>
  ) {
    if (paramName) {
      this.updateQueryParams({
        [paramName]: value === defaultValue ? null : value,
      });
    }
  }

  #sorted(items: T[]): T[] {
    const compareFn = this.sortOptions.find(
      (option) => option.value === this.sort
    )?.compareFn;

    return compareFn ? items.sort(compareFn) : items;
  }

  #validatedUrlValue(
    params: URLSearchParams,
    paramName: string,
    options: readonly { value: string }[]
  ): string | null {
    const value = params.get(paramName);
    return value !== null && options.some((option) => option.value === value)
      ? value
      : null;
  }

  <template>
    {{yield to="aboveFilters"}}

    {{#if this.showFilters}}
      <div
        class={{dConcatClass
          "d-filter-controls"
          (if
            (or this.hasMultipleDropdowns @forceShowDropdownFilterToggle)
            "--dropdowns-in-filter-drawer"
          )
        }}
        {{didInsert this.applyDropdownsFromUrl}}
        {{didUpdate
          this.applyDropdownValues
          @defaultDropdownValue
          @dropdownValue
        }}
      >
        {{#if
          (or this.showTextFilter this.showSort this.showDropdownFilterToggle)
        }}
          <div class="d-filter-controls__inputs">
            {{#if this.showTextFilter}}
              <DFilterInput
                class="d-filter-controls__input"
                placeholder={{@inputPlaceholder}}
                @filterAction={{this.onTextFilterChange}}
                @icons={{hash left="magnifying-glass"}}
                @value={{this.textFilter}}
              />
            {{/if}}

            {{yield to="inlineFilters"}}

            {{#if this.showSort}}
              {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
              {{#if this.siteSettings.enable_new_select_controls}}
                <DSelect
                  class="d-filter-controls__sort"
                  @clearMode="never"
                  @icon="arrow-down-wide-short"
                  @iconOnly={{not this.capabilities.viewport.sm}}
                  @labelField="label"
                  @onChange={{this.changeSort}}
                  @options={{this.sortOptions}}
                  @placement="bottom-end"
                  @selectedIcon="check"
                  @texts={{hash ariaLabel=(i18n "filter_controls.sort_label")}}
                  @value={{this.sort}}
                  @valueField="value"
                  @variant="static"
                >
                  <:listHeader>
                    <div class="d-filter-controls__sort-heading">
                      {{~i18n "filter_controls.sort_label"~}}
                    </div>
                  </:listHeader>
                </DSelect>
              {{else}}
                <SortMenu
                  @label={{this.sortLabel}}
                  @onChange={{this.onSortChange}}
                  @options={{this.sortOptions}}
                  @showLabel={{this.capabilities.viewport.sm}}
                  @value={{this.sort}}
                />
              {{/if}}
            {{/if}}

            {{#if this.showDropdownFilterToggle}}
              <DButton
                aria-expanded={{if this.showFilterDropdowns "true" "false"}}
                class="btn-default d-filter-controls__toggle-filters"
                @action={{this.toggleFilters}}
                @icon={{if
                  this.showDropdownFilter
                  "filter-circle-xmark"
                  "filter"
                }}
                @title="filter_controls.toggle"
                @translatedLabel={{@toggleLabel}}
              />
              {{#if this.showResetButton}}
                <ResetButton
                  @action={{this.resetFilters}}
                  @disabled={{not this.hasActiveFilters}}
                />
              {{/if}}
            {{/if}}
          </div>
        {{/if}}

        {{#if this.showDropdownFilter}}
          <div class="d-filter-controls__dropdowns">
            {{#if this.hasMultipleDropdowns}}
              {{#each-in this.dropdownOptionsByKey as |key options|}}
                <DNativeSelect
                  aria-label={{this.dropdownLabel key}}
                  class={{dConcatClass
                    "d-filter-controls__dropdown"
                    (concat "d-filter-controls__dropdown--" key)
                    (unless
                      (eq
                        (get this.dropdownFilters key) (this.defaultValue key)
                      )
                      "--active"
                    )
                  }}
                  data-dropdown-key={{key}}
                  @includeNone={{false}}
                  @onChange={{fn this.onKeyedDropdownChange key}}
                  @value={{get this.dropdownFilters key}}
                  as |select|
                >
                  {{#each options as |option|}}
                    <select.Option @value={{option.value}}>
                      {{option.label}}
                    </select.Option>
                  {{/each}}
                </DNativeSelect>
              {{/each-in}}
            {{else if this.dropdownOptionList.length}}
              <DNativeSelect
                aria-label={{this.singleDropdownLabel}}
                class={{dConcatClass
                  "d-filter-controls__dropdown"
                  (unless
                    (eq this.dropdownFilter this.defaultDropdownValue)
                    "--active"
                  )
                }}
                @includeNone={{false}}
                @onChange={{this.onSingleDropdownChange}}
                @value={{this.dropdownFilter}}
                as |select|
              >
                {{#each this.dropdownOptionList as |option|}}
                  <select.Option @value={{option.value}}>
                    {{option.label}}
                  </select.Option>
                {{/each}}
              </DNativeSelect>
            {{/if}}

            {{yield to="additionalFilters"}}
          </div>
        {{else if
          (and
            this.showStandaloneAdditionalFilters (has-block "additionalFilters")
          )
        }}
          <div class="d-filter-controls__additional-filters">
            {{yield to="additionalFilters"}}
          </div>
        {{/if}}

        {{#if (and this.showResetButton (not this.showDropdownFilterToggle))}}
          <ResetButton
            @action={{this.resetFilters}}
            @disabled={{not this.hasActiveFilters}}
          />
        {{/if}}

        {{yield to="actions"}}
      </div>
    {{/if}}

    {{yield to="aboveContent"}}

    {{#if this.filteredData.length}}
      {{yield this.filteredData to="content"}}
    {{else if this.showFilters}}
      {{#if (and this.showNoResults this.hasActiveFilters (not @loading))}}
        <div class="d-filter-controls__no-results">
          {{#if @noResultsMessage}}
            <p>{{@noResultsMessage}}</p>
          {{/if}}
          {{#if this.showResetButton}}
            <ResetButton
              @action={{this.resetFilters}}
              @label="filter_controls.reset"
            />
          {{/if}}
        </div>
      {{/if}}
    {{else}}
      {{#if @showCustomEmptyState}}
        {{yield to="customEmptyState"}}
      {{else}}
        {{yield this.array to="content"}}
      {{/if}}
    {{/if}}
  </template>
}
