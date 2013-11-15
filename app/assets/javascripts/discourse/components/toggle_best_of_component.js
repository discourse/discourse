/**
  The controls for toggling the summarized view on/off

  @class DiscourseToggleBestOfComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscourseToggleBestOfComponent = Ember.Component.extend({
  templateName: 'components/discourse-toggle-best-of',
  tagName: 'section',
  classNames: ['information'],
  postStream: Em.computed.alias('topic.postStream'),

  actions: {
    toggleBestOf: function() {
      this.get('postStream').toggleBestOf();
    }
  }
});
