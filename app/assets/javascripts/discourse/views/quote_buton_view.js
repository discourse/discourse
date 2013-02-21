(function() {

  window.Discourse.QuoteButtonView = Discourse.View.extend({
    classNames: ['quote-button'],
    classNameBindings: ['hasBuffer'],
    render: function(buffer) {
      return buffer.push("quote reply");
    },
    hasBuffer: (function() {
      if (this.present('controller.buffer')) {
        return 'visible';
      }
      return null;
    }).property('controller.buffer'),
    willDestroyElement: function() {
      return jQuery(document).unbind("mousedown.quote-button");
    },
    didInsertElement: function() {
      /* Clear quote button if they click elsewhere
      */

      var _this = this;
      return jQuery(document).bind("mousedown.quote-button", function(e) {
        if (jQuery(e.target).hasClass('quote-button')) {
          return;
        }
        if (jQuery(e.target).hasClass('create')) {
          return;
        }
        _this.controller.mouseDown(e);
        _this.set('controller.lastSelected', _this.get('controller.buffer'));
        return _this.set('controller.buffer', '');
      });
    },
    click: function(e) {
      return this.get('controller').quoteText(e);
    }
  });

}).call(this);
