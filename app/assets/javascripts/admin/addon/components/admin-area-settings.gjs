import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import AdminFilteredSiteSettings from "admin/components/admin-filtered-site-settings";
import AdminSiteSettingsChangesBanner from "admin/components/admin-site-settings-changes-banner";
import SiteSetting from "admin/models/site-setting";

export default class AdminAreaSettings extends Component {
  @tracked settings = [];
  @tracked loading = false;
  @tracked showBreadcrumb = this.args.showBreadcrumb ?? true;

  constructor() {
    super(...arguments);
    this.#loadSettings();
  }

  get showSettings() {
    return !this.loading && this.settings.length > 0;
  }

  @action
  async reloadSettings() {
    await this.#loadSettings();
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
      this.settings = [
        {
          name: "All",
          nameKey: "all_results",
          siteSettings: result.site_settings.map((setting) =>
            SiteSetting.create(setting)
          ),
        },
      ];
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn(`Failed to load settings with error: ${error}`);
    } finally {
      this.loading = false;
    }
  }

  get filter() {
    return this.args.filter ?? "";
  }

  @action
  adminSettingsFilterChangedCallback(filterData) {
    this.args.adminSettingsFilterChangedCallback(filterData.filter);
  }

  <template>
    {{#if this.showBreadcrumb}}
      <DBreadcrumbsItem @path={{@path}} @label={{i18n "settings"}} />
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
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          <AdminConfigAreaEmptyList
            @emptyLabelTranslated={{i18n "admin.settings.not_found"}}
          />
        </ConditionalLoadingSpinner>
      {{/if}}
    </div>

    <AdminSiteSettingsChangesBanner />
  </template>
}
