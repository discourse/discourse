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
        $(e).magnificPopup({
          type: 'image',
          closeOnContentClick: true,

          image: {
            titleSrc: function(item) {
              return item.el.attr('title') + ' &middot; <a class="image-source-link" href="' + item.src + '" target="_blank">' + I18n.t("lightbox.download") + '</a>';
            }
          }

        });
      });
    });
  }
};
