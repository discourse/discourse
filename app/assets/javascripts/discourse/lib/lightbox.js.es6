import loadScript from 'discourse/lib/load-script';

export default function($elem) {
  $("a.lightbox", $elem).each(function(i, e) {
    loadScript("/javascripts/jquery.magnific-popup-min.js").then(function() {
      const $e = $(e);
      // do not lightbox spoiled images
      if ($e.parents(".spoiler").length > 0 || $e.parents(".spoiled").length > 0) { return; }

      $e.magnificPopup({
        type: "image",
        closeOnContentClick: false,
        removalDelay: 300,
        mainClass: "mfp-zoom-in",

        callbacks: {
          open() {
            const wrap = this.wrap,
                  img = this.currItem.img,
                  maxHeight = img.css("max-height");

            wrap.on("click.pinhandler", "img", function() {
              wrap.toggleClass("mfp-force-scrollbars");
              img.css("max-height", wrap.hasClass("mfp-force-scrollbars") ? "none" : maxHeight);
            });
          },
          beforeClose() {
            this.wrap.off("click.pinhandler");
            this.wrap.removeClass("mfp-force-scrollbars");
          }
        },

        image: {
          titleSrc(item) {
            const href = item.el.data("download-href") || item.src;
            let src = [item.el.attr("title"), $("span.informations", item.el).text().replace('x', '&times;')];
            if (!Discourse.SiteSettings.prevent_anons_from_downloading_files || Discourse.User.current()) {
              src.push('<a class="image-source-link" href="' + href + '">' + I18n.t("lightbox.download") + '</a>');
            }
            return src.join(' &middot; ');
          }
        }

      });
    });
  });
}
