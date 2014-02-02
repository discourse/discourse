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
  bulkSelectEnabled: Em.computed.alias('controllers.discoveryTopics.bulkSelectEnabled'),

  checked: function(key, value) {
    var selected = this.get('controllers.discoveryTopics.selected'),
        topic = this.get('model');

    if (arguments.length > 1) {
      if (value) {
        selected.addObject(topic);
      } else {
        selected.removeObject(topic);
      }
    }
    return selected.contains(topic);
  }.property('controllers.discoveryTopics.selected.length'),

  actions: {
    toggleStar: function() {
      this.get('model').toggleStar();
    }
  }
});

