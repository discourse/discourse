import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";

export default class AdminSiteSettingsFilterControls extends Component {
  @tracked filter = "";
  @tracked onlyOverridden = false;

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
  onToggleOverridden(event) {
    this.onlyOverridden = event.target.checked;
    this.onChangeFilter();
  }

  <template>
    <div class="admin-controls admin-site-settings-filter-controls">
      <div class="controls">
        <div class="inline-form">
          {{#if @showMenu}}
            <DButton
              @action={{@onToggleMenu}}
              @icon="bars"
              class="menu-toggle"
            />
          {{/if}}
          <Input
            @id="setting-filter"
            @type="text"
            autocomplete="off"
            @value={{this.filter}}
            @placeholderKey="type_to_filter"
            {{on "input" this.onChangeFilter}}
            class="no-blur"
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
            {{on "click" this.onToggleOverridden}}
          />
          {{i18n "admin.settings.show_overriden"}}
        </label>
      </div>
    </div>
  </template>
}
