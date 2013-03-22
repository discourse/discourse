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
    Begin watching for scroll events. By default they will be called at max every 100ms.
    call with {debounce: N} for a diff time

    @method bindScrolling
  */
  bindScrolling: function(opts) {
    var onScroll,
      _this = this;

    opts = opts || {debounce: 100};

    if (opts.debounce) {
      onScroll = Discourse.debounce(function() { return _this.scrolled(); }, 100);
    } else {
      onScroll = function(){ return _this.scrolled(); };
    }

    $(document).bind('touchmove.discourse', onScroll);
    $(window).bind('scroll.discourse', onScroll);

    // resize is should also fire this cause it causes scrolling of sorts
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


