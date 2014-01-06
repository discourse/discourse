/**
  Controller of the top page

  @class TopController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.TopController = Discourse.ObjectController.extend({

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

  showThisYear: function() {
    if (Discourse.User.current()) {
      return !Discourse.User.currentProp("hasBeenSeenInTheLastMonth");
    } else {
      return true;
    }
  }.property(),


});
