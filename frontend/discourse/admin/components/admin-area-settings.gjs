import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import AdminFilteredSiteSettings from "discourse/admin/components/admin-filtered-site-settings";
import AdminSiteSettingsChangesBanner from "discourse/admin/components/admin-site-settings-changes-banner";
import SiteSetting from "discourse/admin/models/site-setting";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";

export default class AdminAreaSettings extends Component {
  @service adminSiteSettingStore;

  @tracked settings = [];
  @tracked loading = false;

  constructor() {
    super(...arguments);
    this.#loadSettings();
  }

  get showBreadcrumb() {
    return this.args.showBreadcrumb ?? true;
  }

  get showSettings() {
    return !this.loading && this.settings.length > 0;
  }

  get filter() {
    return this.args.filter ?? "";
  }

  @action
  async reloadSettings() {
    await this.#loadSettings();
  }

  @action
  adminSettingsFilterChangedCallback(filterData) {
    this.args.adminSettingsFilterChangedCallback(filterData.filter);
  }

  @bind
  async #loadSettings() {
    this.loading = true;
    try {
      const result = await ajax("/admin/config/site_settings.json", {
        data: {
          filter_area: this.args.area,
          plugin: this.args.plugin,
          categories: this.args.categories,
        },
      });
      const siteSettings = result.site_settings.map((setting) =>
        SiteSetting.create(setting)
      );
      this.adminSiteSettingStore.register(siteSettings);
      this.settings =
        this.args.plugin && !this.args.area
          ? this.#groupBySection(siteSettings)
          : [this.#untitledGroup(siteSettings)];
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn(`Failed to load settings with error: ${error}`);
    } finally {
      this.loading = false;
    }
  }

  #untitledGroup(siteSettings = []) {
    return { nameKey: "all_results", siteSettings };
  }

  #groupBySection(siteSettings) {
    const groups = new Map([["", this.#untitledGroup()]]);

    siteSettings.forEach((setting) => {
      const section = setting.section ?? "";

      if (!groups.has(section)) {
        groups.set(section, {
          name: i18n(`admin.site_settings.sections.${section}`),
          nameKey: section,
          siteSettings: [],
        });
      }

      groups.get(section).siteSettings.push(setting);
    });

    return [...groups.values()].filter((group) => group.siteSettings.length);
  }

  <template>
    {{#if this.showBreadcrumb}}
      <DBreadcrumbsItem @label={{i18n "settings"}} @path={{@path}} />
    {{/if}}

    <div
      class="content-body admin-config-area__settings admin-detail pull-left"
      {{didUpdate this.reloadSettings @plugin}}
      {{didUpdate this.reloadSettings @area}}
    >
      {{#if this.showSettings}}
        <AdminFilteredSiteSettings
          @initialFilter={{this.filter}}
          @onFilterChanged={{this.adminSettingsFilterChangedCallback}}
          @settings={{this.settings}}
        />
      {{else}}
        <DConditionalLoadingSpinner @condition={{this.loading}}>
          <AdminConfigAreaEmptyList
            @emptyLabelTranslated={{i18n "admin.settings.not_found"}}
          />
        </DConditionalLoadingSpinner>
      {{/if}}
    </div>

    <AdminSiteSettingsChangesBanner />
  </template>
}
