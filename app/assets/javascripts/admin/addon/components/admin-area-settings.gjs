import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import AdminFilteredSiteSettings from "admin/components/admin-filtered-site-settings";
import SiteSetting from "admin/models/site-setting";

export default class AdminAreaSettings extends Component {
  @service siteSettings;
  @service router;
  @tracked settings = [];
  @tracked filter = "";
  @tracked loading = false;
  @tracked showBreadcrumb = this.args.showBreadcrumb ?? true;

  constructor() {
    super(...arguments);
    this.#loadSettings();
  }

  get showSettings() {
    return !this.loading && this.settings.length > 0;
  }

  @bind
  async #loadSettings() {
    this.loading = true;
    this.filter = this.args.filter;
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
  </template>
}
