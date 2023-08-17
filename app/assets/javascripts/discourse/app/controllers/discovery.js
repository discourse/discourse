import { inject as service } from "@ember/service";
import { alias, equal } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import Category from "discourse/models/category";
import DiscourseURL from "discourse/lib/url";

export default class DiscoveryController extends Controller {
  @service router;

  @controller("navigation/category") navigationCategory;

  @equal("router.currentRouteName", "discovery.categories")
  viewingCategoriesList;

  @alias("navigationCategory.category") category;
  @alias("navigationCategory.noSubcategories") noSubcategories;

  loading = false;

  @action
  loadingBegan() {
    this.set("loading", true);
  }

  @action
  loadingComplete() {
    this.set("loading", false);
  }

  showMoreUrl(period) {
    let url = "",
      category = this.category;

    if (category) {
      url = `/c/${Category.slugFor(category)}/${category.id}${
        this.noSubcategories ? "/none" : ""
      }/l`;
    }

    url += "/top";

    const urlSearchParams = new URLSearchParams();

    for (const [key, value] of Object.entries(
      this.router.currentRoute.queryParams
    )) {
      if (typeof value !== "undefined") {
        urlSearchParams.set(key, value);
      }
    }

    urlSearchParams.set("period", period);

    return `${url}?${urlSearchParams.toString()}`;
  }

  get showLoadingSpinner() {
    return (
      this.get("loading") &&
      this.siteSettings.page_loading_indicator === "spinner"
    );
  }

  @action
  changePeriod(p) {
    DiscourseURL.routeTo(this.showMoreUrl(p));
  }
}
