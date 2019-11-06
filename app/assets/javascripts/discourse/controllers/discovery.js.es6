import { alias, not } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import DiscourseURL from "discourse/lib/url";

export default Controller.extend({
  discoveryTopics: inject("discovery/topics"),
  navigationCategory: inject("navigation/category"),
  application: inject(),

  loading: false,

  category: alias("navigationCategory.category"),
  noSubcategories: alias("navigationCategory.noSubcategories"),

  loadedAllItems: not("discoveryTopics.model.canLoadMore"),

  _showFooter: function() {
    this.set("application.showFooter", this.loadedAllItems);
  }.observes("loadedAllItems"),

  showMoreUrl(period) {
    let url = "",
      category = this.category;
    if (category) {
      url =
        "/c/" +
        Discourse.Category.slugFor(category) +
        (this.noSubcategories ? "/none" : "") +
        "/l";
    }
    url += "/top/" + period;
    return url;
  },

  actions: {
    changePeriod(p) {
      DiscourseURL.routeTo(this.showMoreUrl(p));
    }
  }
});
