import Controller, { inject as controller } from "@ember/controller";
import { alias, equal, not } from "@ember/object/computed";
import { action } from "@ember/object";
import Category from "discourse/models/category";
import DiscourseURL from "discourse/lib/url";
import { inject as service } from "@ember/service";

export default Controller.extend({
  discoveryTopics: controller("discovery/topics"),
  navigationCategory: controller("navigation/category"),
  application: controller(),
  router: service(),
  viewingCategoriesList: equal(
    "router.currentRouteName",
    "discovery.categories"
  ),
  loading: false,

  category: alias("navigationCategory.category"),
  noSubcategories: alias("navigationCategory.noSubcategories"),

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

    let queryParams = this.router.currentRoute.queryParams;
    queryParams.period = period;
    if (Object.keys(queryParams).length) {
      url =
        `${url}?` +
        Object.keys(queryParams)
          .map((key) => `${key}=${queryParams[key]}`)
          .join("&");
    }

    return url;
  },

  actions: {
    changePeriod(p) {
      DiscourseURL.routeTo(this.showMoreUrl(p));
    },
  },
});
