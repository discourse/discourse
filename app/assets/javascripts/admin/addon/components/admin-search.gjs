import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import icon from "discourse/helpers/d-icon";
import autoFocus from "discourse/modifiers/auto-focus";

export default class AdminSearch extends Component {
  @service adminSearchDataSource;

  @tracked filter = "";
  @tracked searchResults = [];
  @tracked showTypeFilters = false;
  @tracked showPageType = true;
  @tracked showSettingType = true;
  @tracked showThemeType = true;
  @tracked showComponentType = true;
  @tracked showReportType = true;

  constructor() {
    super(...arguments);
    this.adminSearchDataSource.buildMap();
  }

  get visibleTypes() {
    const types = [];
    if (this.showPageType) {
      types.push("page");
    }
    if (this.showSettingType) {
      types.push("setting");
    }
    if (this.showThemeType) {
      types.push("theme");
    }
    if (this.showComponentType) {
      types.push("component");
    }
    if (this.showReportType) {
      types.push("report");
    }
    return types;
  }

  @action
  toggleTypeFilters() {
    this.showTypeFilters = !this.showTypeFilters;
  }

  @action
  toggleTypeFilter(type) {
    this[type] = !this[type];
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
    this.searchResults = this.adminSearchDataSource.search(this.filter, {
      types: this.visibleTypes,
    });
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
      <DButton
        class="btn-flat"
        @icon="filter"
        @action={{this.toggleTypeFilters}}
      />
    </div>

    {{#if this.showTypeFilters}}
      <div class="admin-search__type-filter">
        <button
          class="admin-search__type-filter-item {{if this.showPageType 'is-active'}}"
          {{on "click" (fn this.toggleTypeFilter "showPageType")}}
        >
          <span class="admin-search__filter-select">
            {{icon (if this.showPageType "check" "far-circle")}}
          </span>
          Pages
        </button>

        <button
          class="admin-search__type-filter-item {{if this.showSettingType 'is-active'}}"
          {{on "click" (fn this.toggleTypeFilter "showSettingType")}}
        >
          <span class="admin-search__filter-select">
            {{icon (if this.showSettingType "check" "far-circle")}}
          </span>
          Settings
        </button>

        <button
          class="admin-search__type-filter-item {{if this.showThemeType 'is-active'}}"
          {{on "click" (fn this.toggleTypeFilter "showThemeType")}}
        >
          <span class="admin-search__filter-select">
            {{icon (if this.showThemeType "check" "far-circle")}}
          </span>
          Themes
        </button>

        <button
          class="admin-search__type-filter-item {{if this.showComponentType 'is-active'}}"
          {{on "click" (fn this.toggleTypeFilter "showComponentType")}}
        >
          <span class="admin-search__filter-select">
            {{icon (if this.showComponentType "check" "far-circle")}}
          </span>
          Components
        </button>

        <button
          class="admin-search__type-filter-item {{if this.showReportType 'is-active'}}"
          {{on "click" (fn this.toggleTypeFilter "showReportType")}}
        >
          <span class="admin-search__filter-select">
            {{icon (if this.showReportType "check" "far-circle")}}
          </span>
          Reports
        </button>
      </div>
    {{/if}}

    <div class="admin-search__results">
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
    </div>
  </template>
}
