/**
  Helper object for lightboxes.

  @class Lightbox
  @namespace Discourse
  @module Discourse
**/
Discourse.Lightbox = {
  apply: function($elem) {
    var _this = this;
    $('a.lightbox', $elem).each(function(i, e) {
      $LAB.script("/javascripts/jquery.magnific-popup-min.js").wait(function() {
        $(e).magnificPopup({
          type: 'image',
          closeOnContentClick: true
        });
      });
    });
  }
};
