/**
  The parent route for all discovery routes. Handles the logic for showing
  the loading spinners.

  @class DiscoveryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryRoute = Discourse.Route.extend({
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
      var topicsController = this.controllerFor('discoveryTopics');
      this.controllerFor('composer').open({
        categoryId: topicsController.get('category.id'),
        action: Discourse.Composer.CREATE_TOPIC,
        draft: topicsController.get('draft'),
        draftKey: topicsController.get('draft_key'),
        draftSequence: topicsController.get('draft_sequence')
      });
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

