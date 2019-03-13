import loadScript from "discourse/lib/load-script";
import { escapeExpression } from "discourse/lib/utilities";
import { renderIcon } from "discourse-common/lib/icon-library";

export default function($elem) {
  if (!$elem) {
    return;
  }
  const original_meta = $("meta[name=viewport]");
  loadScript("/javascripts/jquery.magnific-popup.min.js").then(function() {
    const spoilers = $elem.find(".spoiler a.lightbox, .spoiled a.lightbox");
    $elem
      .find("a.lightbox")
      .not(spoilers)
      .magnificPopup({
        type: "image",
        closeOnContentClick: false,
        removalDelay: 300,
        mainClass: "mfp-zoom-in",

        gallery: {
          enabled: true
        },

        callbacks: {
          open() {
            original_meta.replaceWith(
              '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
            );
            const wrap = this.wrap,
              img = this.currItem.img,
              maxHeight = img.css("max-height");

            wrap.on("click.pinhandler", "img", function() {
              wrap.toggleClass("mfp-force-scrollbars");
              img.css(
                "max-height",
                wrap.hasClass("mfp-force-scrollbars") ? "none" : maxHeight
              );
            });
          },
          beforeClose() {
            $("meta[name=viewport]").replaceWith(original_meta);
            this.wrap.off("click.pinhandler");
            this.wrap.removeClass("mfp-force-scrollbars");
          }
        },

        image: {
          titleSrc(item) {
            const href = item.el.data("download-href") || item.src;
            let src = [
              escapeExpression(item.el.attr("title")),
              $("span.informations", item.el).text()
            ];
            if (
              !Discourse.SiteSettings.prevent_anons_from_downloading_files ||
              Discourse.User.current()
            ) {
              src.push(
                '<a class="image-source-link" href="' +
                  href +
                  '">' +
                  renderIcon("string", "download") +
                  I18n.t("lightbox.download") +
                  "</a>"
              );
            }
            return src.join(" &middot; ");
          }
        }
      });
  });
}
