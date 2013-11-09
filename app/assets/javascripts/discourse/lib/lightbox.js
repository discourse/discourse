/**
  Helper object for lightboxes.

  @class Lightbox
  @namespace Discourse
  @module Discourse
**/
Discourse.Lightbox = {
  apply: function($elem) {
    $LAB.script("/javascripts/jquery.magnific-popup-min.js").wait(function() {
      $('a.lightbox', $elem).each(function(i, e) {
        $(e).magnificPopup({ type: 'image', closeOnContentClick: true });
      });
    });
  }
};
