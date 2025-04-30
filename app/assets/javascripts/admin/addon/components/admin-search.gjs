import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { and, not } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { escapeExpression } from "discourse/lib/utilities";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";
import AdminSearchFilters from "admin/components/admin-search-filters";
import { ADMIN_SEARCH_RESULT_TYPES } from "admin/lib/constants";

const ADMIN_SEARCH_FILTERS = "admin_search_filters";

export default class AdminSearch extends Component {
  @service adminSearchDataSource;
  @service keyValueStore;
  @service router;

  @tracked filter = this.args.initialFilter ?? "";
  @tracked searchResults = [];
  @tracked showFilters = true;
  @tracked loading = false;
  typeFilters = new TrackedObject({
    page: true,
    setting: true,
    theme: true,
    component: true,
    report: true,
  });

  constructor() {
    super(...arguments);

    if (this.keyValueStore.getItem(ADMIN_SEARCH_FILTERS)) {
      this.typeFilters = new TrackedObject(
        JSON.parse(this.keyValueStore.getItem(ADMIN_SEARCH_FILTERS))
      );
    }

    this.adminSearchDataSource.buildMap().then(() => {
      if (this.filter !== "") {
        this.loading = true;
        this.runSearch();
      }
    });
  }

  get visibleTypes() {
    return Object.keys(this.typeFilters).filter(
      (type) => this.typeFilters[type]
    );
  }

  get showLoadingSpinner() {
    return !this.adminSearchDataSource.isLoaded || this.loading;
  }

  get noResultsDescription() {
    return i18n("admin.search.no_results", {
      filter: escapeExpression(this.filter),
    });
  }

  @action
  toggleFilters() {
    this.showFilters = !this.showFilters;
  }

  @action
  toggleTypeFilter(type) {
    this.typeFilters[type] = !this.typeFilters[type];

    const allFiltersShowing = Object.values(this.typeFilters).every(
      (value) => value
    );

    if (!allFiltersShowing) {
      this.keyValueStore.setItem(
        ADMIN_SEARCH_FILTERS,
        JSON.stringify(this.typeFilters)
      );
    } else {
      this.keyValueStore.removeItem(ADMIN_SEARCH_FILTERS);
    }

    this.search();
  }

  @action
  changeSearchTerm(event) {
    this.searchResults = [];
    this.filter = event.target.value;
    if (this.filter.length > 0) {
      this.runSearch();
    }
  }

  @action
  search() {
    discourseDebounce(this, this.#search, INPUT_DELAY);
  }

  // TODO (martin) Maybe we can move ListHandler / iterate-list from chat into
  // core so we can use it here too.
  @action
  handleResultKeyDown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      event.target.click();
    }

    if (event.key === "ArrowUp") {
      event.preventDefault();
      event.stopPropagation();
      const previousResult = event.target.parentElement.previousElementSibling;
      if (previousResult) {
        previousResult.firstElementChild?.focus();
      } else {
        document.querySelector(".admin-search__input-field").focus();
      }
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();
      event.stopPropagation();
      event.target.parentElement.nextElementSibling.firstElementChild?.focus();
    }
  }

  @action
  handleSearchKeyDown(event) {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      event.stopPropagation();
      document
        .querySelector(".admin-search__result .admin-search__result-link")
        .focus();
    }

    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      this.router.transitionTo("adminSearch.index", {
        queryParams: { filter: this.filter },
      });
    }
  }

  @action
  initialFilterUpdated() {
    this.filter = this.args.initialFilter;
    this.runSearch();
  }

  @action
  runSearch() {
    this.loading = true;
    this.search();
  }

  #search() {
    this.searchResults = this.adminSearchDataSource.search(this.filter, {
      types: this.visibleTypes,
    });
    this.loading = false;
  }

  <template>
    <div
      class="admin-search__input-container"
      {{didUpdate this.initialFilterUpdated @initialFilter}}
    >
      <div class="admin-search__input-group">
        {{icon "magnifying-glass" class="admin-search__input-icon"}}
        <input
          type="text"
          class="admin-search__input-field"
          value={{this.filter}}
          {{autoFocus}}
          {{on "input" this.changeSearchTerm}}
          {{on "keydown" this.handleSearchKeyDown}}
          placeholder={{i18n "admin.search.instructions"}}
        />
      </div>
      <DButton class="btn-flat" @icon="filter" @action={{this.toggleFilters}} />
    </div>
    {{#if @fullPageLink}}
      <LinkTo
        @route="adminSearch"
        @query={{hash filter=this.filter}}
        class="admin-search__full-page-link"
      >
        {{i18n "admin.search.full_page_link"}}
      </LinkTo>
    {{/if}}

    {{#if this.showFilters}}
      <AdminSearchFilters
        @toggleTypeFilter={{this.toggleTypeFilter}}
        @typeFilters={{this.typeFilters}}
        @types={{ADMIN_SEARCH_RESULT_TYPES}}
      />
    {{/if}}

    <div class="admin-search__results">
      <ConditionalLoadingSpinner @condition={{this.showLoadingSpinner}}>
        {{#each this.searchResults as |result|}}
          <div class="admin-search__result" data-result-type={{result.type}}>
            <a
              href={{result.url}}
              {{on "keydown" this.handleResultKeyDown}}
              class="admin-search__result-link"
              tabindex="0"
            >
              <div class="admin-search__result-name">
                {{#if result.icon}}
                  {{icon result.icon}}
                {{/if}}
                <span
                  class="admin-search__result-name-label"
                >{{result.label}}</span>
              </div>
              {{#if result.description}}
                <div class="admin-search__result-description">{{htmlSafe
                    result.description
                  }}</div>
              {{/if}}
            </a>
          </div>
        {{/each}}
        {{#if (and (not this.searchResults) this.filter)}}
          <p class="admin-search__no-results">
            {{this.noResultsDescription}}
          </p>
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
