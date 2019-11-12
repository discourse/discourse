import loadScript from "discourse/lib/load-script";
import { escapeExpression } from "discourse/lib/utilities";
import { renderIcon } from "discourse-common/lib/icon-library";
import { isAppWebview, postRNWebviewMessage } from "discourse/lib/utilities";
import { spinnerHTML } from "discourse/helpers/loading-spinner";
import User from "discourse/models/user";

export default function($elem) {
  if (!$elem) {
    return;
  }

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
        tClose: I18n.t("lightbox.close"),
        tLoading: spinnerHTML,

        gallery: {
          enabled: true,
          tPrev: I18n.t("lightbox.previous"),
          tNext: I18n.t("lightbox.next"),
          tCounter: I18n.t("lightbox.counter")
        },

        ajax: {
          tError: I18n.t("lightbox.content_load_error")
        },

        callbacks: {
          open() {
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

            if (isAppWebview()) {
              postRNWebviewMessage(
                "headerBg",
                $(".mfp-bg").css("background-color")
              );
            }
          },
          beforeClose() {
            this.wrap.off("click.pinhandler");
            this.wrap.removeClass("mfp-force-scrollbars");
            if (isAppWebview()) {
              postRNWebviewMessage(
                "headerBg",
                $(".d-header").css("background-color")
              );
            }
          }
        },

        image: {
          tError: I18n.t("lightbox.image_load_error"),
          titleSrc(item) {
            const href = item.el.data("download-href") || item.src;
            let src = [
              escapeExpression(item.el.attr("title")),
              $("span.informations", item.el).text()
            ];
            if (
              !Discourse.SiteSettings.prevent_anons_from_downloading_files ||
              User.current()
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
