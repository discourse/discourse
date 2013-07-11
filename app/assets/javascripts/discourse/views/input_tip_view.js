/**
  This view handles rendering a tip when a field on a form is invalid

  @class InputTipView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.InputTipView = Discourse.View.extend({
  classNameBindings: [':tip', 'good', 'bad'],

  shouldRerender: Discourse.View.renderIfChanged('validation'),
  bad: Em.computed.alias('validation.failed'),
  good: Em.computed.not('bad'),

  render: function(buffer) {
    var reason = this.get('validation.reason');
    if (reason) {
      var icon = this.get('good') ? 'icon-ok' : 'icon-remove';
      return buffer.push("<i class=\"icon " + icon + "\"></i> " + reason);
    }
  }
});

Discourse.View.registerHelper('inputTip', Discourse.InputTipView);