import Controller from "@ember/controller";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import { debounce } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class AdminSiteSettingsController extends Controller {
  @service router;

  @alias("model.filteredSettings") visibleSiteSettings;
  @alias("model.filtersApplied") filtersApplied;

  @debounce(INPUT_DELAY)
  filterContent(filterData) {
    if (this._skipBounce) {
      this.set("_skipBounce", false);
    } else {
      const currentParams = this.router.currentRoute.queryParams;
      const queryParams = {
        filter: filterData.filter || undefined,
        onlyOverridden: filterData.onlyOverridden || undefined,
      };

      const paramsChanged =
        currentParams.filter !== queryParams.filter ||
        currentParams.onlyOverridden !== queryParams.onlyOverridden;

      if (!this.isDestroyed && paramsChanged) {
        this.router.transitionTo(this.router.currentRouteName, { queryParams });
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
