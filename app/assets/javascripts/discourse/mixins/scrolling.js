/**
  This mixin adds support for being notified every time the browser window
  is scrolled.

  @class Scrolling
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
    opts = opts || {debounce: 100};

    var scrollingMixin = this;
    var onScrollMethod;

    if (opts.debounce) {
      onScrollMethod = Discourse.debounce(function() {
        return scrollingMixin.scrolled();
      }, opts.debounce);
    } else {
      onScrollMethod = function() {
        return scrollingMixin.scrolled();
      };
    }

    Discourse.ScrollingDOMMethods.bindOnScroll(onScrollMethod);
  },

  /**
    Stop watching for scroll events.

    @method unbindScrolling
  */
  unbindScrolling: function() {
    Discourse.ScrollingDOMMethods.unbindOnScroll();
  }

});


/**
  This object provides the DOM methods we need for our Mixin to bind to scrolling
  methods in the browser. By removing them from the Mixin we can test them
  easier.

  @class ScrollingDOMMethods
  @module Discourse
**/
Discourse.ScrollingDOMMethods = {

  bindOnScroll: function(onScrollMethod) {
    $(document).bind('touchmove.discourse', onScrollMethod);
    $(window).bind('scroll.discourse', onScrollMethod);
  },

  unbindOnScroll: function() {
    $(window).unbind('scroll.discourse');
    $(document).unbind('touchmove.discourse');
  }

};