// Dear traveller, you are entering a zone where we are at war with the browser
// the browser is insisting on positioning scrollTop per the location it was in
// the past, we are insisting on it being where we want it to be
// The hack is just to keep trying over and over to position the scrollbar (up to 1 minute)
//
// The root cause is that a "refresh" on a topic page will almost never be at the
// same position it was in the past, the URL points to the post at the top of the
// page, so a refresh will try to bring that post into view causing drift
//
// Additionally if you loaded multiple batches of posts, on refresh they will not
// be loaded.
//
// This hack leads to a slight jerky experience, however other workarounds are more
// complex, the 2 options we have are
//
// 1. onbeforeunload ensure we are scrolled to the right spot
// 2. give up on the scrollbar and implement it ourselves (something that will happen)

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
        startedAt = new Date().getTime(),
        i = 0;

    $(window).scrollTop(previousTop);

    var within = function(threshold,x,y) {
      return Math.abs(x-y) < threshold;
    };

    var interval = setInterval(function() {
      i = i + 1;

      var top = self.elementTop(),
          scrollTop = $(window).scrollTop();

      if (typeof(top) === "undefined") {
        $('body,html').off(scrollEvents);
        clearInterval(interval);
        return;
      }

      if (!within(4, top, previousTop) || !within(4, scrollTop, top)) {
        $(window).scrollTop(top);
        // animating = true;
        // $('html,body').animate({scrollTop: parseInt(top,10)+'px'}, 200, 'swing', function(){
        //   animating = false;
        // });
        previousTop = top;
      }

      // We commit suicide after 3s just to clean up
      var nowTime = new Date().getTime();
      if (nowTime - startedAt > 1000) {
        $('body,html').off(scrollEvents);
        clearInterval(interval);
      }

    }, 50);

    $('body,html').off(scrollEvents).on(scrollEvents, function(e){
      if ( e.which > 0 || e.type === "mousedown" || e.type === "mousewheel" || e.type === "touchmove") {
        $('body,html').off(scrollEvents);
        clearInterval(interval);
      }
    });

  };

  exports.LockOn = LockOn;

})(window);
