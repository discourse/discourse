import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import AsyncContent from "discourse/components/async-content";
import DPageSubheader from "discourse/components/d-page-subheader";
import basePath from "discourse/helpers/base-path";
import { ajax } from "discourse/lib/ajax";
import { currentThemeId, listThemes } from "discourse/lib/theme-selector";
import { i18n } from "discourse-i18n";
import AdminFilterControls from "admin/components/admin-filter-controls";
import DTooltip from "float-kit/components/d-tooltip";

export default class ThemeSiteSettings extends Component {
  @service site;

  @tracked themesWithSiteSettingOverrides = null;
  @tracked themeableSiteSettings = null;

  get themes() {
    return listThemes(this.site);
  }

  get currentThemeIdValue() {
    return currentThemeId();
  }

  get currentTheme() {
    return this.themes.find((theme) => {
      return eq(theme.id, this.currentThemeIdValue);
    });
  }

  @action
  async loadThemeSiteSettings() {
    let url = "/admin/config/customize/theme-site-settings.json";
    const response = await ajax(url, {
      method: "GET",
    });
    this.themeableSiteSettings = response.themeable_site_settings.map(
      (setting) => {
        return {
          name: setting.humanized_name,
          value: setting,
        };
      }
    );
    this.themesWithSiteSettingOverrides =
      response.themes_with_site_setting_overrides;
    return this.themesWithSiteSettingOverrides;
  }

  isLastThemeSettingOverride(overrides, theme) {
    return theme === overrides.themes.at(-1);
  }

  filterableSettings(settings) {
    if (!settings) {
      return [];
    }

    const filterableSettings = [];
    for (const [settingName, overrides] of Object.entries(settings)) {
      filterableSettings.push({
        humanized_name: overrides.humanized_name,
        name: settingName,
        description: overrides.description,
        default: overrides.default,
        themeNames:
          overrides.themes?.map((t) => t.theme_name.toLowerCase()).join(",") ||
          "",
        themes: overrides.themes,
      });
    }

    return filterableSettings;
  }

  <template>
    <div class="theme-site-settings">
      <DPageSubheader
        @descriptionLabel={{i18n
          "admin.theme_site_settings.help"
          currentTheme=this.currentTheme.name
          basePath=basePath
          currentThemeId=this.currentThemeIdValue
        }}
      />

      <AsyncContent @asyncData={{this.loadThemeSiteSettings}}>
        <:content as |content|>
          <AdminFilterControls
            @array={{this.filterableSettings content}}
            @searchableProps={{array
              "humanized_name"
              "name"
              "description"
              "themeNames"
            }}
            @inputPlaceholder={{i18n "admin.theme_site_settings.filter"}}
            @noResultsMessage={{i18n
              "admin.theme_site_settings.filter_no_results"
            }}
          >
            <:content as |filteredSettings|>
              <table class="d-admin-table admin-theme-site-settings">
                <thead>
                  <tr>
                    <th>{{i18n "admin.theme_site_settings.setting"}}</th>
                    <th>{{i18n "admin.theme_site_settings.default_value"}}</th>
                    <th>{{i18n "admin.theme_site_settings.overridden_by"}}</th>
                  </tr>
                </thead>
                <tbody>
                  {{#each filteredSettings as |fs|}}
                    <tr
                      class="admin-theme-site-settings-row d-admin-row__content"
                      data-setting-name={{fs.name}}
                    >
                      <td class="admin-theme-site-settings-row__setting">
                        <p class="setting-label">{{fs.humanized_name}}</p>
                        <div
                          class="setting-description"
                        >{{fs.description}}</div>
                      </td>
                      <td class="admin-theme-site-settings-row__default">
                        {{fs.default}}
                      </td>
                      <td class="admin-theme-site-settings-row__overridden">
                        {{#each fs.themes as |theme|}}
                          <DTooltip>
                            <:trigger>
                              <LinkTo
                                @route="adminCustomizeThemes.show"
                                @models={{array "themes" theme.theme_id}}
                                class="theme-link"
                                data-theme-id={{theme.theme_id}}
                              >
                                {{theme.theme_name}}
                              </LinkTo>
                            </:trigger>
                            <:content>
                              {{i18n
                                "admin.theme_site_settings.overridden_value"
                                value=theme.value
                              }}
                            </:content>
                          </DTooltip>
                          {{#unless
                            (this.isLastThemeSettingOverride fs theme)
                          }},{{/unless}}
                        {{/each}}
                        {{#unless fs.themes}}
                          -
                        {{/unless}}
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            </:content>
          </AdminFilterControls>
        </:content>
      </AsyncContent>
    </div>
  </template>
}
