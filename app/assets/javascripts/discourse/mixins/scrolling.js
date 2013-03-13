/**
  This mixin adds support for being notified every time the browser window
  is scrolled.

  @class Discourse.Scrolling
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
Discourse.Scrolling = Em.Mixin.create({

  /**
    Begin watching for scroll events. They will be called at max every 100ms.

    @method bindScrolling
  */
  bindScrolling: function() {
    var onScroll,
      _this = this;
    onScroll = Discourse.debounce(function() { return _this.scrolled(); }, 100);
    $(document).bind('touchmove.discourse', onScroll);
    $(window).bind('scroll.discourse', onScroll);
  },

  /**
    Begin watching for scroll events. They will be called at max every 100ms.

    @method unbindScrolling
  */
  unbindScrolling: function() {
    $(window).unbind('scroll.discourse');
    $(document).unbind('touchmove.discourse');
  }

});


