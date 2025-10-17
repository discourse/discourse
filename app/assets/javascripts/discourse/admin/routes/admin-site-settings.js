import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import SiteSettingFilter from "admin/lib/site-setting-filter";
import SiteSetting from "admin/models/site-setting";

export default class AdminSiteSettingsRoute extends DiscourseRoute {
  @service siteSettingChangeTracker;

  queryParams = {
    filter: {
      replace: true,
      refreshModel: true,
    },
    onlyOverridden: {
      replace: true,
      refreshModel: true,
    },
  };

  _siteSettings = null;

  titleToken() {
    return i18n("admin.config.site_settings.title");
  }

  async model(params) {
    this._siteSettings ??= await SiteSetting.findAll();

    return {
      filteredSettings: this.filterSettings(
        params.filter,
        params.onlyOverridden
      ),
      filtersApplied: params.filter || params.onlyOverridden,
    };
  }

  @action
  async willTransition(transition) {
    if (
      this.siteSettingChangeTracker.hasUnsavedChanges &&
      transition.from.name !== transition.to.name
    ) {
      transition.abort();

      await this.siteSettingChangeTracker.confirmTransition();

      transition.retry();
    }
  }

  @action
  filterSettings(filter, onlyOverridden) {
    const settingFilter = new SiteSettingFilter(this._siteSettings);

    return settingFilter.filterSettings(filter, {
      onlyOverridden: onlyOverridden === "true",
    });
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.set("filter", "");
    }
  }
}
