/**
  Helper object for lightboxes.

  @class Lightbox
  @namespace Discourse
  @module Discourse
**/
Discourse.Lightbox = {
  apply: function($elem) {
    var _this = this;
    return $('a.lightbox', $elem).each(function(i, e) {
      return $LAB.script("/javascripts/jquery.colorbox-min.js").wait(function() {
        return $(e).colorbox();
      });
    });
  }
}


