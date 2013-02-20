
/* Helper object for light boxes. Uses highlight.js which is loaded
*/


/* on demand.
*/


(function() {

  window.Discourse.Lightbox = {
    apply: function($elem) {
      var _this = this;
      return jQuery('a.lightbox', $elem).each(function(i, e) {
        return $LAB.script("/javascripts/jquery.colorbox-min.js").wait(function() {
          return jQuery(e).colorbox();
        });
      });
    }
  };

}).call(this);
