import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { ajax } from "discourse/lib/ajax";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import AdminFilteredSiteSettings from "admin/components/admin-filtered-site-settings";
import SiteSetting from "admin/models/site-setting";

export default class AdminConfigAreasEmojisSettings extends Component {
  @service siteSettings;
  @tracked settings;

  @bind
  loadSettings() {
    ajax("/admin/config/site_settings.json", {
      data: {
        filter_area: "emojis",
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
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/config/emojis/settings"
      @label={{i18n "settings"}}
    />

    <div
      class="content-body admin-config-area__settings admin-detail pull-left"
      {{didInsert this.loadSettings}}
    >
      {{#if this.settings}}
        <AdminFilteredSiteSettings
          @initialFilter={{@initialFilter}}
          @onFilterChanged={{@onFilterChanged}}
          @settings={{this.settings}}
        />
      {{/if}}
    </div>
  </template>
}
