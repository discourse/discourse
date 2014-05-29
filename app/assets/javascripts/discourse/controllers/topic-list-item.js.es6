/**
  Handles displaying of a topic as a list item

  @class TopicListItemController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
export default Ember.ObjectController.extend({
  needs: ['discovery/topics'],

  canStar: Em.computed.alias('controllers.discovery/topics.currentUser.id'),
  bulkSelectEnabled: Em.computed.alias('controllers.discovery/topics.bulkSelectEnabled'),

  checked: function(key, value) {
    var selected = this.get('controllers.discovery/topics.selected'),
        topic = this.get('model');

    if (arguments.length > 1) {
      if (value) {
        selected.addObject(topic);
      } else {
        selected.removeObject(topic);
      }
    }
    return selected.contains(topic);
  }.property('controllers.discovery/topics.selected.length'),

  titleColSpan: function() {
    // Uncategorized pinned topics will span the title and category column in the topic list.
    return (!this.get('controllers.discovery/topics.hideCategory') &&
             this.get('model.isPinnedUncategorized') ? 2 : 1);
  }.property('controllers.discovery/topics.hideCategory', 'model.isPinnedUncategorized'),

  hideCategory: function() {
    return this.get('controllers.discovery/topics.hideCategory') || this.get('titleColSpan') > 1;
  }.property('controllers.discovery/topics.hideCategory', 'titleColSpan'),

  actions: {
    toggleStar: function() {
      this.get('model').toggleStar();
    }
  }
});

