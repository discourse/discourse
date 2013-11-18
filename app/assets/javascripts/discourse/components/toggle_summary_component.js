/**
  The controls for toggling the summarized view on/off

  @class DiscourseToggleSummaryComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscourseToggleSummaryComponent = Ember.Component.extend({
  templateName: 'components/discourse-toggle-summary',
  tagName: 'section',
  classNames: ['information'],
  postStream: Em.computed.alias('topic.postStream'),

  actions: {
    toggleSummary: function() {
      this.get('postStream').toggleSummary();
    }
  }
});
