/**
  The controls for toggling the supression of deleted posts

  @class ToggleDeletedComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
export default Ember.Component.extend({
  layoutName: 'components/toggle-deleted',
  tagName: 'section',
  classNames: ['information'],
  postStream: Em.computed.alias('topic.postStream'),

  actions: {
    toggleDeleted: function() {
      this.get('postStream').toggleDeleted();
    }
  }
});
