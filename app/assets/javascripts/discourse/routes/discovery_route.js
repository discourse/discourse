/**
  The parent route for all discovery routes. Handles the logic for showing
  the loading spinners.

  @class DiscoveryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryRoute = Discourse.Route.extend(Discourse.OpenComposer, {
  actions: {
    loading: function() {
      this.controllerFor('discovery').set('loading', true);
    },

    loadingComplete: function() {
      this.controllerFor('discovery').set('loading', false);
    },

    didTransition: function() {
      this.send('loadingComplete');
    },

    // clear a pinned topic
    clearPin: function(topic) {
      topic.clearPin();
    },

    createTopic: function() {
      this.openComposer(this.controllerFor('discoveryTopics'));
    },

    changeBulkTemplate: function(w) {
      this.render(w, {into: 'topicBulkActions', outlet: 'bulkOutlet', controller: 'topicBulkActions'});
    },

    showBulkActions: function() {
      var selected = this.controllerFor('discoveryTopics').get('selected');
      Discourse.Route.showModal(this, 'topicBulkActions', selected);
      this.send('changeBulkTemplate', 'modal/bulk_actions_buttons');
    }
  }

});

