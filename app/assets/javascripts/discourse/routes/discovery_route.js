/**
  The parent route for all discovery routes. Handles the logic for showing
  the loading spinners.

  @class DiscoveryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryRoute = Discourse.Route.extend(Discourse.ScrollTop, Discourse.OpenComposer, {

  redirect: function() { Discourse.redirectIfLoginRequired(this); },

  beforeModel: function(transition) {
    if (transition.targetName.indexOf("discovery.top") === -1 &&
        Discourse.User.currentProp("should_be_redirected_to_top")) {
      Discourse.User.currentProp("should_be_redirected_to_top", false);
      this.transitionTo("discovery.top");
    }
  },

  actions: {
    loading: function() {
      var controller = this.controllerFor('discovery');

      // If we're already loading don't do anything
      if (controller.get('loading')) { return; }

      controller.set('loading', true);
      controller.set('scheduledSpinner', Ember.run.later(controller, function() {
        this.set('loadingSpinner', true);
      },500));
    },

    loadingComplete: function() {
      var controller = this.controllerFor('discovery');
      Ember.run.cancel(controller.get('scheduledSpinner'));
      controller.setProperties({ loading: false, loadingSpinner: false });
      this._scrollTop();
    },

    didTransition: function() {
      this.send('loadingComplete');
    },

    // clear a pinned topic
    clearPin: function(topic) {
      topic.clearPin();
    },

    createTopic: function() {
      this.openComposer(this.controllerFor('discovery/topics'));
    },

    changeBulkTemplate: function(w) {
      var controllerName = w.replace('modal/', ''),
          factory = this.container.lookupFactory('controller:' + controllerName);

      this.render(w, {into: 'topicBulkActions', outlet: 'bulkOutlet', controller: factory ? controllerName : 'topic-bulk-actions'});
    },

    showBulkActions: function() {
      var selected = this.controllerFor('discovery/topics').get('selected');
      Discourse.Route.showModal(this, 'topicBulkActions', selected);
      this.send('changeBulkTemplate', 'modal/bulk_actions_buttons');
    }
  }

});

