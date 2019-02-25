import DiscourseURL from "discourse/lib/url";

export default Ember.Controller.extend({
  discoveryTopics: Ember.inject.controller("discovery/topics"),
  navigationCategory: Ember.inject.controller("navigation/category"),
  application: Ember.inject.controller(),

  loading: false,

  category: Ember.computed.alias("navigationCategory.category"),
  noSubcategories: Ember.computed.alias("navigationCategory.noSubcategories"),

  loadedAllItems: Ember.computed.not("discoveryTopics.model.canLoadMore"),

  _showFooter: function() {
    this.set("application.showFooter", this.get("loadedAllItems"));
  }.observes("loadedAllItems"),

  showMoreUrl(period) {
    let url = "",
      category = this.get("category");
    if (category) {
      url =
        "/c/" +
        Discourse.Category.slugFor(category) +
        (this.get("noSubcategories") ? "/none" : "") +
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
