/**
  This view handles rendering a tip when a field on a form is invalid

  @class InputTipView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.InputTipView = Discourse.View.extend({
  templateName: 'input_tip',
  classNameBindings: [':tip', 'good', 'bad'],

  good: (function() {
    return !this.get('validation.failed');
  }).property('validation'),

  bad: (function() {
    return this.get('validation.failed');
  }).property('validation'),

  triggerRender: (function() {
    return this.rerender();
  }).observes('validation'),

  render: function(buffer) {
    var icon, reason;
    if (reason = this.get('validation.reason')) {
      icon = this.get('good') ? 'icon-ok' : 'icon-remove';
      return buffer.push("<i class=\"icon " + icon + "\"></i> " + reason);
    }
  }
});


