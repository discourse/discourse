(function (exports) {

  var scrollEvents = "scroll.lock-on touchmove.lock-on mousedown.lock-on wheel.lock-on DOMMouseScroll.lock-on mousewheel.lock-on keyup.lock-on";

  var LockOn = function(selector, options) {
    this.selector = selector;
    this.options = options || {};
  };

  LockOn.prototype.elementTop = function() {
    var offsetCalculator = this.options.offsetCalculator,
        selected = $(this.selector);

    if (selected && selected.offset && selected.offset()) {
      return selected.offset().top - (offsetCalculator ? offsetCalculator() : 0);
    }
  };

  LockOn.prototype.lock = function() {
    var self = this,
        previousTop = this.elementTop(),
        startedAt = new Date().getTime()
        i = 0;

    $(window).scrollTop(previousTop);

    var interval = setInterval(function() {
      i = i + 1;

      var top = self.elementTop(),
          scrollTop = $(window).scrollTop();

      if (typeof(top) === "undefined") {
        $('body,html').off(scrollEvents)
        clearInterval(interval);
        return;
      }

      if ((top !== previousTop) || (scrollTop !== top)) {
        $(window).scrollTop(top);
        previousTop = top;
      }

      // We commit suicide after 1s just to clean up
      var nowTime = new Date().getTime();
      if (nowTime - startedAt > 1000) {
        $('body,html').off(scrollEvents)
        clearInterval(interval);
      }

    }, 50);

    $('body,html').off(scrollEvents).on(scrollEvents, function(e){
      if ( e.which > 0 || e.type === "mousedown" || e.type === "mousewheel" || e.type === "touchmove") {
        $('body,html').off(scrollEvents);
        clearInterval(interval);
      }
    })

  };

  exports.LockOn = LockOn;

})(window);
