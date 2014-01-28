/**
  Handles displaying of a topic as a list item

  @class TopicListItemController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicListItemController = Ember.ObjectController.extend({
  needs: ['discoveryTopics'],

  canStar: Em.computed.alias('controllers.discoveryTopics.currentUser.id'),
  hideCategory: Em.computed.alias('controllers.discoveryTopics.hideCategory'),

  actions: {
    toggleStar: function() {
      this.get('model').toggleStar();
    }
  }
});

