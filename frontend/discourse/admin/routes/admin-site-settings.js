import { action } from "@ember/object";
import { service } from "@ember/service";
import SiteSettingFilter from "discourse/admin/lib/site-setting-filter";
import SiteSetting from "discourse/admin/models/site-setting";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

/**
 * @typedef {Object} SiteSettingCategory
 * @property {string} nameKey
 * @property {string} name
 * @property {import("discourse/admin/models/site-setting").default[]} siteSettings
 * @property {number | string} [count]
 * @property {boolean} [hasMore]
 * @property {number} [maxResults]
 */
export default class AdminSiteSettingsRoute extends DiscourseRoute {
  @service adminSiteSettingStore;
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
    dependsOn: {
      replace: true,
      refreshModel: true,
    },
  };

  /** @type {SiteSettingCategory[] | null} */
  _siteSettings = null;

  titleToken() {
    return i18n("admin.config.site_settings.title");
  }

  async model(params) {
    if (!this._siteSettings) {
      this._siteSettings = await SiteSetting.findAll();
      this.adminSiteSettingStore.register(
        this._siteSettings.flatMap((category) => category.siteSettings)
      );
    }

    return {
      filteredSettings: this.filterSettings(
        params.filter,
        params.onlyOverridden,
        params.dependsOn
      ),
      filtersApplied:
        params.filter || params.onlyOverridden || params.dependsOn,
      activeFilter: params.filter ?? "",
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

  /** @returns {SiteSettingCategory[]} */
  @action
  filterSettings(filter, onlyOverridden, dependsOn) {
    const settingFilter = new SiteSettingFilter(this._siteSettings);

    return settingFilter.filterSettings(filter, {
      onlyOverridden: onlyOverridden === "true",
      dependsOn,
    });
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.set("filter", "");
    }
  }
}
