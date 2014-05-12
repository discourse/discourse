/**
  The controller for discoverying 'Top' topics

  @class DiscoveryTopController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
export default Discourse.DiscoveryController.extend({
  needs: ['discovery'],

  actions: {
    refresh: function() {
      var self = this;

      // Don't refresh if we're still loading
      if (this.get('controllers.discovery.loading')) { return; }

      this.send('loading');
      Discourse.TopList.find().then(function(top_lists) {
        self.set('model', top_lists);
        self.send('loadingComplete');
      });
    }
  },

  hasDisplayedAllTopLists: Em.computed.and('content.yearly', 'content.monthly', 'content.weekly', 'content.daily')
});
