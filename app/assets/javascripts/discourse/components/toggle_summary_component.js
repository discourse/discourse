/**
  The controls for toggling the summarized view on/off

  @class ToggleSummaryComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
Discourse.ToggleSummaryComponent = Ember.View.extend({
  templateName: 'components/toggle-summary',
  tagName: 'section',
  classNames: ['information'],
  postStream: Em.computed.alias('topic.postStream'),

  init: function() {
    this._super();
    this.set('context', this);
    this.set('controller', this);
  },

  actions: {
    toggleSummary: function() {
      this.get('postStream').toggleSummary();
    }
  }
});
