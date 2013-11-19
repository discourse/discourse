/**
  The controls for toggling the summarized view on/off

  @class ToggleSummaryComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
Discourse.ToggleSummaryComponent = Ember.Component.extend({
  templateName: 'components/toggle-summary',
  tagName: 'section',
  classNames: ['information'],
  postStream: Em.computed.alias('topic.postStream'),

  actions: {
    toggleSummary: function() {
      this.get('postStream').toggleSummary();
    }
  }
});
