import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { inject as controller } from "@ember/controller";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class AdminSiteSettingsFilterControls extends Component {
  @controller adminSiteSettings;

  @tracked filter = this.args.initialFilter || "";
  @tracked onlyOverridden = false;
  @tracked
  currentCategoryName = this.adminSiteSettings.categoryNameKey
    ? this.adminSiteSettings.categoryNameKey
    : null;

  @action
  clearFilter() {
    this.filter = "";
    this.onlyOverridden = false;
    this.onChangeFilter();
  }

  @action
  onChangeFilter() {
    this.args.onChangeFilter({
      filter: this.filter,
      onlyOverridden: this.onlyOverridden,
    });
  }

  @action
  onChangeFilterInput(event) {
    this.filter = event.target.value;
    this.onChangeFilter();
  }

  @action
  onToggleOverridden(event) {
    this.onlyOverridden = event.target.checked;
    this.onChangeFilter();
  }

  @action
  runInitialFilter() {
    if (this.args.initialFilter !== this.filter) {
      this.filter = this.args.initialFilter;
    }
    this.onChangeFilter();
  }

  @action
  transitionToCategory(category) {
    this.currentCategoryName = category;
    this.adminSiteSettings.transitionToCategory(category);
  }

  get siteSettingsCategories() {
    return this.adminSiteSettings.visibleSiteSettings.map((category) => {
      return {
        id: category.nameKey,
        name: i18n(`admin.site_settings.categories.${category.nameKey}`),
      };
    });
  }

  get translatedCurrentCategoryName() {
    return i18n(`admin.site_settings.categories.${this.currentCategoryName}`);
  }

  <template>
    <div
      class="admin-controls admin-site-settings-filter-controls"
      {{didInsert this.runInitialFilter}}
      {{didUpdate this.runInitialFilter @initialFilter}}
    >
      <div class="controls">
        {{#if this.currentCategoryName}}
          <ComboBox
            @value={{this.translatedCurrentCategoryName}}
            @content={{this.siteSettingsCategories}}
            @onChange={{this.transitionToCategory}}
          />
        {{/if}}
        <div class="inline-form">
          <input
            {{on "input" this.onChangeFilterInput}}
            id="setting-filter"
            class="no-blur admin-site-settings-filter-controls__input"
            placeholder={{i18n "type_to_filter"}}
            autocomplete="off"
            type="text"
            value={{this.filter}}
          />
          <DButton
            @action={{this.clearFilter}}
            @label="admin.site_settings.clear_filter"
            id="clear-filter"
            class="btn-default"
          />
        </div>
      </div>

      <div class="search controls">
        <label>
          <Input
            @type="checkbox"
            @checked={{this.onlyOverridden}}
            class="toggle-overridden"
            id="setting-filter-toggle-overridden"
            {{on "click" this.onToggleOverridden}}
          />
          {{i18n "admin.settings.show_overriden"}}
        </label>
      </div>
    </div>
  </template>
}
