import Controller from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { service } from "@ember/service";
import { debounce } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class AdminSiteSettingsController extends Controller {
  @service router;

  @computed("model.filteredSettings")
  get visibleSiteSettings() {
    return this.model?.filteredSettings;
  }

  set visibleSiteSettings(value) {
    set(this, "model.filteredSettings", value);
  }

  @computed("model.filtersApplied")
  get filtersApplied() {
    return this.model?.filtersApplied;
  }

  set filtersApplied(value) {
    set(this, "model.filtersApplied", value);
  }

  @debounce(INPUT_DELAY)
  filterContent(filterData) {
    if (this._skipBounce) {
      this.set("_skipBounce", false);
    } else {
      const currentParams = this.router.currentRoute.queryParams;
      const queryParams = {
        filter: filterData.filter || undefined,
        onlyOverridden: filterData.onlyOverridden || undefined,
        dependsOn: filterData.dependsOn || undefined,
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
