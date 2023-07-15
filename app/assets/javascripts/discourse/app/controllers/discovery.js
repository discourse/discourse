import Controller, { inject as controller } from "@ember/controller";
import { alias, equal, not } from "@ember/object/computed";
import { action } from "@ember/object";
import Category from "discourse/models/category";
import DiscourseURL from "discourse/lib/url";
import { inject as service } from "@ember/service";

export default Controller.extend({
  // discoveryTopics: controller("discovery/topics"),
  // navigationCategory: controller("navigation/category"),
  application: controller(),
  router: service(),
  viewingCategoriesList: equal(
    "router.currentRouteName",
    "discovery.categories"
  ),
  loading: false,

  // category: alias("navigationCategory.category"),
  // noSubcategories: alias("navigationCategory.noSubcategories"),

  loadedAllItems: not("discoveryTopics.model.canLoadMore"),

  @action
  loadingBegan() {
    this.set("loading", true);
    this.set("application.showFooter", false);
  },

  @action
  loadingComplete() {
    this.set("loading", false);
    this.set("application.showFooter", this.loadedAllItems);
  },

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
  },
});
