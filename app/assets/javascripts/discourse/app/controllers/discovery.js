import { inject as service } from "@ember/service";
import { alias, equal, not } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import Category from "discourse/models/category";
import DiscourseURL from "discourse/lib/url";

export default class DiscoveryController extends Controller {
  @service router;

  @controller("discovery/topics") discoveryTopics;
  @controller("navigation/category") navigationCategory;
  @controller application;

  @equal("router.currentRouteName", "discovery.categories")
  viewingCategoriesList;

  @alias("navigationCategory.category") category;
  @alias("navigationCategory.noSubcategories") noSubcategories;
  @not("discoveryTopics.model.canLoadMore") loadedAllItems;

  loading = false;

  @action
  loadingBegan() {
    this.set("loading", true);
    this.set("application.showFooter", false);
  }

  @action
  loadingComplete() {
    this.set("loading", false);
    this.set("application.showFooter", this.loadedAllItems);
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
