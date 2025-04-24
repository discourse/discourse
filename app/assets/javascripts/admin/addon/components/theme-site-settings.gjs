import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import AsyncContent from "discourse/components/async-content";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { humanizedSettingName } from "discourse/lib/site-settings-utils";
import { currentThemeId, listThemes } from "discourse/lib/theme-selector";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class ThemeSiteSettings extends Component {
  @service site;
  @service router;

  @tracked themeSiteSettings = null;
  @tracked selectedSettingName = this.args.initialSelectedSettingName || null;
  @tracked themeableSiteSettings = null;

  get context() {
    if (!this.selectedSettingName) {
      return {};
    }
    return { settingName: this.selectedSettingName };
  }

  get themes() {
    return listThemes(this.site);
  }

  get ctaRouteModels() {
    return ["themes", this.selectedThemeId];
  }

  get currentThemeIdValue() {
    return currentThemeId();
  }

  @action
  async loadThemeSiteSettings(context) {
    let url = "/admin/config/theme-site-settings.json";
    if (context.settingName) {
      url += `?setting_name=${context.settingName}`;
    }
    const response = await ajax(url, {
      method: "GET",
    });
    this.themeableSiteSettings = response.themeable_site_settings.map(
      (setting) => {
        return {
          name: humanizedSettingName(setting),
          value: setting,
        };
      }
    );
    this.themeSiteSettings = response.theme_site_settings;
    return this.themeSiteSettings;
  }

  @action
  updateSelectedSettingName(value) {
    this.selectedSettingName = value;
    this.router.transitionTo({ queryParams: { selectedSettingName: value } });
  }

  <template>
    <div class="theme-site-settings">
      <ComboBox
        @labelProperty="name"
        @valueProperty="value"
        @content={{this.themeableSiteSettings}}
        @value={{this.selectedSettingName}}
        @id="themeable_site_settings"
        @onChange={{this.updateSelectedSettingName}}
        @options={{hash none="admin.theme_site_settings.select_setting"}}
      />
      <AsyncContent
        @asyncData={{this.loadThemeSiteSettings}}
        @context={{this.context}}
      >
        <:content as |content|>
          <DPageSubheader
            @descriptionLabel={{i18n "admin.theme_site_settings.help"}}
          />
          <table class="d-admin-table">
            <thead>
              <tr>
                <th>{{i18n "admin.theme_site_settings.theme"}}</th>
                <th>{{i18n "admin.theme_site_settings.value"}}</th>
                <th>{{i18n "admin.theme_site_settings.is_overridden"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each content as |setting|}}
                <tr
                  class={{concatClass
                    "d-admin-row__content admin-theme-site-settings__table-row"
                    (unless setting.is_default "--overridden")
                  }}
                >
                  <td>
                    {{setting.theme_name}}
                    {{#if (eq setting.theme_id this.currentThemeIdValue)}}
                      *
                    {{/if}}
                  </td>
                  <td>
                    {{setting.value}}
                  </td>
                  <td>
                    {{#if setting.is_default}}
                      {{i18n "no_value"}}
                    {{else}}
                      {{i18n "yes_value"}}
                    {{/if}}
                  </td>

                  <td class="d-admin-row__controls">
                    <div class="d-admin-row__controls-options">
                      <DButton
                        class="btn-default btn-small admin-theme-site-settings__edit"
                        @route="adminCustomizeThemes.show"
                        @routeModels={{array "themes" setting.theme_id}}
                        @label="admin.config_areas.flags.edit"
                      />
                    </div>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </:content>
        <:empty>
        </:empty>
      </AsyncContent>
    </div>
  </template>
}
