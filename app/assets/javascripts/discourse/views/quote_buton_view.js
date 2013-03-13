/**
  This view is used for rendering the pop-up quote button

  @class QuoteButtonView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.QuoteButtonView = Discourse.View.extend({
  classNames: ['quote-button'],
  classNameBindings: ['hasBuffer'],

  render: function(buffer) {
    buffer.push("quote reply");
  },

  hasBuffer: (function() {
    if (this.present('controller.buffer')) return 'visible';
    return null;
  }).property('controller.buffer'),

  willDestroyElement: function() {
    $(document).unbind("mousedown.quote-button");
  },

  didInsertElement: function() {
    // Clear quote button if they click elsewhere
    var _this = this;
    return $(document).bind("mousedown.quote-button", function(e) {
      if ($(e.target).hasClass('quote-button')) return;
      if ($(e.target).hasClass('create')) return;
      _this.controller.mouseDown(e);
      _this.set('controller.lastSelected', _this.get('controller.buffer'));
      return _this.set('controller.buffer', '');
    });
  },

  click: function(e) {
    return this.get('controller').quoteText(e);
  }

});


