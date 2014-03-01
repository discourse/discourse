/**
  The controller for discoverying 'Top' topics

  @class DiscoveryTopController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryTopController = Discourse.DiscoveryController.extend({

  actions: {
    refresh: function() {
      var self = this;
      this.send('loading');
      Discourse.TopList.find().then(function(top_lists) {
        self.set('model', top_lists);
        self.send('loadingComplete');
      });
    }
  },

  redirectedToTopPageReason: function() {
    // no need for a reason if the default homepage is 'top'
    if (Discourse.Utilities.defaultHomepage() === 'top') { return null; }
    // check if the user is authenticated
    if (Discourse.User.current()) {
      if (Discourse.User.currentProp('trust_level') === 0) {
        return I18n.t('filters.top.redirect_reasons.new_user');
      } else if (!Discourse.User.currentProp('hasBeenSeenInTheLastMonth')) {
        return I18n.t('filters.top.redirect_reasons.not_seen_in_a_month');
      }
    }
    // no reason detected
    return null;
  }.property(),

  hasDisplayedAllTopLists: Em.computed.and('content.yearly', 'content.monthly', 'content.weekly', 'content.daily')
});
