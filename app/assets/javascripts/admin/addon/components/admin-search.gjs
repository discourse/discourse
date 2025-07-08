import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, not } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import icon from "discourse/helpers/d-icon";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { escapeExpression } from "discourse/lib/utilities";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";

export default class AdminSearch extends Component {
  @service adminSearchDataSource;
  @service keyValueStore;
  @service router;

  @tracked filter = this.args.initialFilter ?? "";
  @tracked searchResults = [];
  @tracked showFilters = true;
  @tracked loading = false;
  @tracked dataReady = false;

  constructor() {
    super(...arguments);

    this.adminSearchDataSource.buildMap().then(() => {
      this.dataReady = true;
      if (this.filter !== "") {
        this.loading = true;
        this.runSearch();
      }
    });
  }

  get noResultsDescription() {
    return i18n("admin.search.no_results", {
      filter: escapeExpression(this.filter),
    });
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
    this.searchResults = this.adminSearchDataSource.search(this.filter);
    this.loading = false;
  }

  get showLoadingSpinner() {
    return this.filter !== "" && (this.loading || !this.dataReady);
  }

  <template>
    <div
      class="admin-search__input-container
        {{if this.searchResults '--has-results'}}
        "
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
    </div>
    <div class="sr-only" aria-live="polite" role="status">
      {{#if this.searchResults}}
        {{i18n
          "admin.search.result_count"
          count=this.searchResults.length
          filter=this.filter
        }}
      {{/if}}
      {{#if
        (and
          this.filter
          (not this.searchResults.length)
          (not this.showLoadingSpinner)
        )
      }}
        {{this.noResultsDescription}}
      {{/if}}
    </div>
    {{#if
      (and
        this.filter
        (not this.searchResults.length)
        (not this.showLoadingSpinner)
      )
    }}
      <p class="admin-search__no-results" aria-live="polite" role="status">
        {{this.noResultsDescription}}
      </p>
    {{/if}}
    <div
      class="admin-search__results {{if this.searchResults '--has-results'}}"
    >
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
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
