import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import i18n from "discourse-common/helpers/i18n";

export default class AdminSiteSettingsFilterControls extends Component {
  @tracked filter = this.args.initialFilter || "";
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

  @action
  runInitialFilter() {
    this.onChangeFilter();
  }

  <template>
    <div
      class="admin-controls admin-site-settings-filter-controls"
      {{didInsert this.runInitialFilter}}
    >
      <div class="controls">
        <div class="inline-form">
          {{#if @showMenu}}
            <DButton
              @action={{@onToggleMenu}}
              @icon="bars"
              class="menu-toggle"
            />
          {{/if}}
          <TextField
            @type="text"
            @value={{this.filter}}
            placeholder={{i18n "type_to_filter"}}
            @onChange={{this.onChangeFilter}}
            class="no-blur"
            id="setting-filter"
            autocomplete="off"
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
