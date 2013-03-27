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
    buffer.push('<i class="icon-quote-right"></i>&nbsp;&nbsp;');
    buffer.push(Em.String.i18n("post.quote_reply"));
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
    var quoteButtonView = this;
    return $(document).bind("mousedown.quote-button", function(e) {
      if ($(e.target).hasClass('quote-button')) return;
      if ($(e.target).hasClass('create')) return;
      quoteButtonView.controller.mouseDown(e);
      quoteButtonView.set('controller.lastSelected', quoteButtonView.get('controller.buffer'));
      return quoteButtonView.set('controller.buffer', '');
    });
  },

  click: function(e) {
    e.stopPropagation();
    return this.get('controller').quoteText(e);
  }

});


