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
      var controller = this.controllerFor('discovery');
      
      controller.set('scheduledSpinner', Ember.run.later(controller, function() {
        this.set('loading', true);
      },500));
    },

    loadingComplete: function() {
      var controller = this.controllerFor('discovery');

      Ember.run.cancel(controller.get('scheduledSpinner'));
      controller.set('loading', false);
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
      var controllerName = w.replace('modal/', ''),
          factory = this.container.lookupFactory('controller:' + controllerName);

      this.render(w, {into: 'topicBulkActions', outlet: 'bulkOutlet', controller: factory ? controllerName : 'topicBulkActions'});
    },

    showBulkActions: function() {
      var selected = this.controllerFor('discoveryTopics').get('selected');
      Discourse.Route.showModal(this, 'topicBulkActions', selected);
      this.send('changeBulkTemplate', 'modal/bulk_actions_buttons');
    }
  }

});

