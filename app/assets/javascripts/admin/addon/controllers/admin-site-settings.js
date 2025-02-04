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
  @service currentUser;

  @alias("model") allSiteSettings;

  filter = "";
  visibleSiteSettings = null;
  siteSettingFilter = null;
  showSettingCategorySidebar = !this.currentUser.use_admin_sidebar;

  filterContentNow(filterData, category) {
    this.siteSettingFilter ??= new SiteSettingFilter(this.allSiteSettings);

    if (isEmpty(this.allSiteSettings)) {
      return;
    }

    // We want to land on All by default if admin sidebar is shown, in this
    // case we are hiding the inner site setting category sidebar.
    if (this.showSettingCategorySidebar) {
      if (isEmpty(filterData.filter) && !filterData.onlyOverridden) {
        this.set("visibleSiteSettings", this.allSiteSettings);
        if (this.categoryNameKey === "all_results") {
          this.router.transitionTo("adminSiteSettings");
        }
        return;
      }
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
