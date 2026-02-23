import Component from "@glimmer/component";
import { service } from "@ember/service";
import ThemeSiteSettingEditor from "discourse/admin/components/theme-site-setting-editor";
import { i18n } from "discourse-i18n";

export default class ThemeBuilderSiteSettingsSection extends Component {
  @service themeBuilderState;

  get themeModel() {
    return {
      id: this.themeBuilderState.themeId,
      name: this.themeBuilderState.themeName || "[Draft] Theme Builder",
    };
  }

  get themeSiteSettings() {
    return this.themeBuilderState.themeSiteSettings;
  }

  <template>
    <div class="theme-builder-site-settings-section">
      {{#if this.themeSiteSettings.length}}
        <section class="form-horizontal theme settings">
          {{#each this.themeSiteSettings as |setting|}}
            <ThemeSiteSettingEditor
              @setting={{setting}}
              @model={{this.themeModel}}
              class="theme-site-setting"
            />
          {{/each}}
        </section>
      {{else}}
        <p class="theme-builder-site-settings-section__empty">{{i18n
            "styleguide.theme_builder.site_settings.empty"
          }}</p>
      {{/if}}
    </div>
  </template>
}
