import Controller from "@ember/controller";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { debounce } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import SiteSettingFilter from "discourse/lib/site-setting-filter";

export default class AdminSiteSettingsController extends Controller {
  @service router;

  @alias("model") allSiteSettings;

  filter = "";
  visibleSiteSettings = null;
  siteSettingFilter = null;

  filterContentNow(filterData, category) {
    this.siteSettingFilter ??= new SiteSettingFilter(this.allSiteSettings);

    if (isEmpty(this.allSiteSettings)) {
      return;
    }

    if (isEmpty(filterData.filter) && !filterData.onlyOverridden) {
      this.set("visibleSiteSettings", this.allSiteSettings);
      if (this.categoryNameKey === "all_results") {
        this.router.transitionTo("adminSiteSettings");
      }
      return;
    }

    this.set("filter", filterData.filter);

    const matchesGroupedByCategory = this.siteSettingFilter.filterSettings(
      filterData.filter,
      { onlyOverridden: filterData.onlyOverridden }
    );

    const categoryMatches = matchesGroupedByCategory.findBy(
      "nameKey",
      category
    );

    if (!categoryMatches || categoryMatches.count === 0) {
      category = "all_results";
    }

    this.set("visibleSiteSettings", matchesGroupedByCategory);
    this.router.transitionTo(
      "adminSiteSettingsCategory",
      category || "all_results"
    );
  }

  @debounce(INPUT_DELAY)
  filterContent(filterData) {
    if (this._skipBounce) {
      this.set("_skipBounce", false);
    } else {
      if (!this.isDestroyed) {
        this.filterContentNow(filterData, this.categoryNameKey);
      }
    }
  }

  @action
  filterChanged(filterData) {
    this.filterContent(filterData);
  }

  @action
  toggleMenu() {
    const adminDetail = document.querySelector(".admin-detail");
    ["mobile-closed", "mobile-open"].forEach((state) => {
      adminDetail.classList.toggle(state);
    });
  }
}
