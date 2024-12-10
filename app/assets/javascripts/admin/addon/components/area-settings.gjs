import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { ajax } from "discourse/lib/ajax";
import { isTesting } from "discourse-common/config/environment";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import AdminFilteredSiteSettings from "admin/components/admin-filtered-site-settings";
import SiteSetting from "admin/models/site-setting";

export default class AreaSettings extends Component {
  @service siteSettings;
  @service router;
  @tracked settings = [];
  @tracked filter = "";

  @bind
  loadSettings() {
    ajax("/admin/config/site_settings.json", {
      data: {
        filter_area: this.args.area,
        plugin: this.args.plugin,
        categories: this.args.categories,
      },
    }).then((result) => {
      this.settings = [
        {
          name: "All",
          nameKey: "all_results",
          siteSettings: result.site_settings.map((setting) =>
            SiteSetting.create(setting)
          ),
        },
      ];
    });
    // check if isTesting is required because there is a conflict with the filter query parameter of Qunit
    if (!isTesting()) {
      const url = new URL(window.location.href);
      const params = new URLSearchParams(url.search);
      if (params.has("filter")) {
        this.filter = params.get("filter");
      }
    }
  }

  @action
  filterChangedCallback(filterData) {
    // check if isTesting is required because there is a conflict with the filter query parameter of Qunit
    if (!isTesting()) {
      const url = new URL(window.location.href);
      const params = new URLSearchParams(url.search);
      if (filterData.filter) {
        params.set("filter", filterData.filter);
      } else {
        params.delete("filter");
      }
      url.search = params.toString();
      window.history.pushState({}, "", url);
    }
  }

  <template>
    <DBreadcrumbsItem @path={{@path}} @label={{i18n "settings"}} />

    <div
      class="content-body admin-config-area__settings admin-detail pull-left"
      {{didInsert this.loadSettings}}
    >
      {{#if this.settings}}
        <AdminFilteredSiteSettings
          @initialFilter={{this.filter}}
          @onFilterChanged={{this.filterChangedCallback}}
          @settings={{this.settings}}
        />
      {{/if}}
    </div>
  </template>
}
