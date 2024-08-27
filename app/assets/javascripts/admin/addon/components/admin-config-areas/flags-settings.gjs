import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import SiteSettingFilter from "discourse/lib/site-setting-filter";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import AdminFilteredSiteSettings from "admin/components/admin-filtered-site-settings";
import SiteSetting from "admin/models/site-setting";

export default class AdminConfigAreasFlagsSettings extends Component {
  @service siteSettings;
  @tracked settings;

  @bind
  loadSettings() {
    SiteSetting.findAll({
      categories: ["spam", "rate_limits", "chat"],
    }).then((settings) => {
      this.settings = new SiteSettingFilter(settings).performSearch(
        "flags",
        {}
      );
    });
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/config/flags/settings"
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
