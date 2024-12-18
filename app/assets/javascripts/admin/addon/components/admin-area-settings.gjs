import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
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

  constructor() {
    super(...arguments);
    this.#loadSettings();
  }

  @bind
  async #loadSettings() {
    this.filter = this.args.filter;
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
  }

  @action
  filterChangedCallback(filterData) {
    this.args.filterChangedCallback(filterData.filter);
  }

  <template>
    <DBreadcrumbsItem @path={{@path}} @label={{i18n "settings"}} />

    <div
      class="content-body admin-config-area__settings admin-detail pull-left"
    >
      {{#if this.settings}}
        <AdminFilteredSiteSettings
          @initialFilter={{this.filter}}
          @onFilterChanged={{this.filterChangedCallback}}
          @settings={{this.settings}}
        />
      {{else}}
        <AdminConfigAreaEmptyList
          @emptyLabelTranslated={{i18n "admin.settings.not_found"}}
        />
      {{/if}}
    </div>
  </template>
}
