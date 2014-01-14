/**
  The controller for discoverying "Top" topics

  @class DiscoveryTopController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryTopController = Discourse.ObjectController.extend({
  category:null,

  redirectedToTopPageReason: function() {
    // no need for a reason if the default homepage is "top"
    if (Discourse.Utilities.defaultHomepage() === "top") { return null; }
    // check if the user is authenticated
    if (Discourse.User.current()) {
      if (Discourse.User.currentProp("trust_level") === 0) {
        return I18n.t("filters.top.redirect_reasons.new_user");
      } else if (!Discourse.User.currentProp("hasBeenSeenInTheLastMonth")) {
        return I18n.t("filters.top.redirect_reasons.not_seen_in_a_month");
      }
    }
    // no reason detected
    return null;
  }.property(),

  hasDisplayedAllTopLists: Em.computed.and('content.yearly', 'content.monthly', 'content.weekly', 'content.daily'),

  showMoreUrl: function(period) {
    var url = "", category = this.get("category");
    if (category) { url += category.get("url") + "/l"; }
    url += "/top/" + period;
    return url;
  },

  showMoreDailyUrl: function() { return this.showMoreUrl("daily"); }.property("category.url"),
  showMoreWeeklyUrl: function() { return this.showMoreUrl("weekly"); }.property("category.url"),
  showMoreMonthlyUrl: function() { return this.showMoreUrl("monthly"); }.property("category.url"),
  showMoreYearlyUrl: function() { return this.showMoreUrl("yearly"); }.property("category.url"),
});
