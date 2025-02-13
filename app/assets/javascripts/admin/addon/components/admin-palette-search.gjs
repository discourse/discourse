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

export default class AdminPaletteSearch extends Component {
  @service adminPaletteDataSource;

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
    this.adminPaletteDataSource.buildMap();
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
    this.searchResults = this.adminPaletteDataSource.search(this.filter, {
      types: this.visibleTypes,
    });
  }

  <template>
    <input
      type="text"
      class="admin-palette__search-input"
      {{autoFocus}}
      {{on "input" this.changeSearchTerm}}
    />
    <DButton @icon="filter" @action={{this.toggleTypeFilters}} />

    {{#if this.showTypeFilters}}
      <div class="admin-palette-type-filter">
        <span class="admin-palette-type-filter__page">
          Pages
          <DToggleSwitch
            @state={{this.showPageType}}
            {{on "click" (fn this.toggleTypeFilter "showPageType")}}
          />
        </span>
        <span class="admin-palette-type-filter__setting">
          Settings
          <DToggleSwitch
            @state={{this.showSettingType}}
            {{on "click" (fn this.toggleTypeFilter "showSettingType")}}
          />
        </span>
        <span class="admin-palette-type-filter__theme">
          Themes
          <DToggleSwitch
            @state={{this.showThemeType}}
            {{on "click" (fn this.toggleTypeFilter "showThemeType")}}
          />
        </span>
        <span class="admin-palette-type-filter__component">
          Components
          <DToggleSwitch
            @state={{this.showComponentType}}
            {{on "click" (fn this.toggleTypeFilter "showComponentType")}}
          />
        </span>
        <span class="admin-palette-type-filter__report">
          Reports
          <DToggleSwitch
            @state={{this.showReportType}}
            {{on "click" (fn this.toggleTypeFilter "showReportType")}}
          />
        </span>
      </div>
    {{/if}}

    <div class="admin-palette__search-results">
      {{#each this.searchResults as |result|}}
        <div class="admin-palette__search-result">
          <a href={{result.url}}>
            <div class="admin-palette__name">
              {{#if result.icon}}
                {{icon result.icon}}
              {{/if}}
              <span class="admin-palette__name-label">{{result.label}}</span>
              <span class="admin-palette__type-pill">{{result.type}}</span>
            </div>
            {{#if result.description}}
              <p class="admin-palette__description">{{htmlSafe
                  result.description
                }}</p>
            {{/if}}
          </a>
        </div>
      {{/each}}
    </div>
  </template>
}
