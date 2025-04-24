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
import { humanizedSettingName } from "discourse/lib/site-settings-utils";
import { currentThemeId, listThemes } from "discourse/lib/theme-selector";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class ThemeSiteSettings extends Component {
  @service site;
  @service router;

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
    let url = "/admin/config/theme-site-settings.json";
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
    this.themesWithSiteSettingOverrides =
      response.themes_with_site_setting_overrides;
    return this.themesWithSiteSettingOverrides;
  }

  @action
  joinedThemesOverriding(themesOverriding) {
    return themesOverriding
      .map((theme) => {
        return `<a href="${basePath()}/admin/customize/themes/${
          theme.theme_id
        }" class="theme-link">${theme.theme_name}</a>`;
      })
      .join(", ");
  }

  <template>
    <div class="theme-site-settings">
      <AsyncContent @asyncData={{this.loadThemeSiteSettings}}>
        <:content as |content|>
          <DPageSubheader
            @descriptionLabel={{i18n
              "admin.theme_site_settings.help"
              currentTheme=this.currentTheme.name
              basePath=basePath
              currentThemeId=this.currentThemeIdValue
            }}
          />
          <table class="d-admin-table admin-theme-site-settings">
            <thead>
              <tr>
                <th>{{i18n "admin.theme_site_settings.setting"}}</th>
                <th>{{i18n "admin.theme_site_settings.overridden_by"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each-in content as |settingName overrides|}}
                <tr class="admin-theme-site-settings-row">
                  <td class="admin-theme-site-settings-row__setting">
                    <p class="setting-label">{{humanizedSettingName
                        settingName
                      }}</p>
                    <div
                      class="setting-description"
                    >{{overrides.setting_description}}</div>
                  </td>
                  <td>
                    {{#each overrides.themes as |theme|}}
                      <DTooltip>
                        <:trigger>
                          <LinkTo
                            @route="adminCustomizeThemes.show"
                            @models={{array "theme" theme.theme_id}}
                            class="theme-link"
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
                        (eq theme overrides.themes.lastObject)
                      }},{{/unless}}
                    {{/each}}
                    {{#unless overrides.themes}}
                      -
                    {{/unless}}
                  </td>
                </tr>
              {{/each-in}}
            </tbody>
          </table>
        </:content>
        <:empty>
        </:empty>
      </AsyncContent>
    </div>
  </template>
}
