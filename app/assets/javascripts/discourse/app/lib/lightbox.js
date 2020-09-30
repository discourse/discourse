import loadScript, { loadCSS } from "discourse/lib/load-script";
import { iconHTML } from "discourse-common/lib/icon-library";
import User from "discourse/models/user";

export default function (elem, siteSettings) {
  if (!elem) {
    return;
  }

  loadScript("/javascripts/light-gallery/lightgallery.min.js").then(() => {
    loadScript("/javascripts/light-gallery/lg-zoom.min.js").then(() => {
      loadCSS("/javascripts/light-gallery/lightgallery.min.css").then(() => {
        lightGallery(elem, {
          selector: "*:not(.spoiler):not(.spoiled) a.lightbox",
          mode: "lg-fade",
          speed: "300",
          cssEasing: "cubic-bezier(0.25, 0, 0.25, 1)",
          startClass: "lg-start-fade",
          preload: 10,
          nextHtml: iconHTML("chevron-right"),
          prevHtml: iconHTML("chevron-left"),
          hideBarsDelay: 100000,
          download:
            !siteSettings.prevent_anons_from_downloading_files ||
            User.current(),
        });
      });
    });
  });

  /*

loadScript("/javascripts/jquery.magnific-popup.min.js").then(function () {
  const lightboxes = elem.querySelectorAll(
    "*:not(.spoiler):not(.spoiled) a.lightbox"
  );
  $(lightboxes).magnificPopup({
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
      tCounter: I18n.t("lightbox.counter"),
    },

    ajax: {
      tError: I18n.t("lightbox.content_load_error"),
    },

    callbacks: {
      open() {
        const wrap = this.wrap,
          img = this.currItem.img,
          maxHeight = img.css("max-height");

        wrap.on("click.pinhandler", "img", function () {
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
      },
    },

    image: {
      tError: I18n.t("lightbox.image_load_error"),
      titleSrc(item) {
        const href = item.el.data("download-href") || item.src;
        let src = [
          escapeExpression(item.el.attr("title")),
          $("span.informations", item.el).text(),
        ];
        if (
          !siteSettings.prevent_anons_from_downloading_files ||
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
      },
    },
  });
});

*/
}
