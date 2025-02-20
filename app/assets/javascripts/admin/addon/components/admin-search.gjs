import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";
import AdminSearchFilters from "admin/components/admin-search-filters";
import { RESULT_TYPES } from "admin/services/admin-search-data-source";

export default class AdminSearch extends Component {
  @service adminSearchDataSource;

  @tracked filter = "";
  @tracked searchResults = [];
  @tracked showFilters = false;
  @tracked loading = false;
  @tracked
  typeFilters = new TrackedObject({
    page: true,
    setting: true,
    theme: true,
    component: true,
    report: true,
  });

  constructor() {
    super(...arguments);
    this.adminSearchDataSource.buildMap();
  }

  get visibleTypes() {
    return Object.keys(this.typeFilters).filter(
      (type) => this.typeFilters[type]
    );
  }

  get showLoadingSpinner() {
    return !this.adminSearchDataSource.isLoaded || this.loading;
  }

  @action
  toggleFilters() {
    this.showFilters = !this.showFilters;
  }

  @action
  toggleTypeFilter(type) {
    this.typeFilters[type] = !this.typeFilters[type];
    this.search();
  }

  @action
  changeSearchTerm(event) {
    this.searchResults = [];
    this.filter = event.target.value;
    this.search();
  }

  @action
  search() {
    this.loading = true;
    discourseDebounce(this, this.#search, INPUT_DELAY);
  }

  #search() {
    this.searchResults = this.adminSearchDataSource.search(this.filter, {
      types: this.visibleTypes,
    });
    this.loading = false;
  }

  <template>
    <div class="admin-search__input-container">
      <div class="admin-search__input-group">
          {{icon
            "magnifying-glass"
            class="admin-search__input-icon"
          }}
        <input
          type="text"
          class="admin-search__input-field"
          {{autoFocus}}
          {{on "input" this.changeSearchTerm}}
        />
      </div>
      <DButton class="btn-flat" @icon="filter" @action={{this.toggleFilters}} />
    </div>

    {{#if this.showFilters}}
      <AdminSearchFilters
        @toggleTypeFilter={{this.toggleTypeFilter}}
        @typeFilters={{this.typeFilters}}
        @types={{RESULT_TYPES}}
      />
    {{/if}}

    <div class="admin-search__results">
      <ConditionalLoadingSpinner @condition={{this.showLoadingSpinner}}>
        {{#each this.searchResults as |result|}}
          <div class="admin-search__result">
            <a href={{result.url}}>
              <div class="admin-search__result-name">
                {{#if result.icon}}
                  {{icon result.icon}}
                {{/if}}
                <span class="admin-search__result-name-label">{{result.label}}</span>
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
