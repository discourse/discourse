
/* Use this mixin if you want to be notified every time the user scrolls the window
*/


(function() {

  window.Discourse.Scrolling = Em.Mixin.create({
    bindScrolling: function() {
      var onScroll,
        _this = this;
      onScroll = Discourse.debounce(function() {
        return _this.scrolled();
      }, 100);
      jQuery(document).bind('touchmove.discourse', onScroll);
      return jQuery(window).bind('scroll.discourse', onScroll);
    },
    unbindScrolling: function() {
      jQuery(window).unbind('scroll.discourse');
      return jQuery(document).unbind('touchmove.discourse');
    }
  });

}).call(this);
