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

  hasDisplayedAllTopLists: Em.computed.and('content.yearly', 'content.monthly', 'content.weekly', 'content.daily')
});
