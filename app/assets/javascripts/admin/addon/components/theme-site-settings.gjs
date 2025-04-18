import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AsyncContent from "discourse/components/async-content";
import { ajax } from "discourse/lib/ajax";
import { currentThemeId, listThemes } from "discourse/lib/theme-selector";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import ComboBox from "select-kit/components/combo-box";

export default class ThemeSiteSettings extends Component {
  @service site;

  @tracked themeSiteSettings = null;
  @tracked selectedThemeId = currentThemeId();

  get context() {
    return { themeId: this.selectedThemeId };
  }

  get themes() {
    return listThemes(this.site);
  }

  get ctaRouteModels() {
    return ["themes", this.selectedThemeId];
  }

  @action
  async loadThemeSiteSettings(context) {
    const themeSiteSettings = await ajax(
      `/admin/config/theme-site-settings.json?theme_id=${context.themeId}`,
      {
        method: "GET",
      }
    );
    return themeSiteSettings;
  }

  @action
  updateSelectedThemeId(value) {
    this.selectedThemeId = value;
  }

  <template>
    <div class="theme-site-settings">
      <ComboBox
        @valueProperty="id"
        @labelProperty="name"
        @content={{this.themes}}
        @value={{this.selectedThemeId}}
        @id="user_chat_sounds"
        @onChange={{this.updateSelectedThemeId}}
      />
      <AsyncContent
        @asyncData={{this.loadThemeSiteSettings}}
        @context={{this.context}}
      >
        <:content as |content|>
          <table class="d-admin-table">
            <thead>
              <tr>
                <th>{{i18n "admin.theme_site_settings.name"}}</th>
                <th>{{i18n "admin.theme_site_settings.value"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each content as |setting|}}
                <tr>
                  <td>{{setting.name}}</td>
                  <td>{{setting.value}}</td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </:content>
        <:empty>
          <AdminConfigAreaEmptyList
            @ctaLabel="admin.theme_site_settings.add"
            @ctaRoute="adminCustomizeThemes.show"
            @ctaRouteModels={{this.ctaRouteModels}}
            @emptyLabel="admin.theme_site_settings.no_overrides"
          />
        </:empty>
      </AsyncContent>
    </div>
  </template>
}
