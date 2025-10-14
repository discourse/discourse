import { waitForPromise } from "@ember/test-waiters";
import $ from "jquery";
import { spinnerHTML } from "discourse/helpers/loading-spinner";
import { isTesting } from "discourse/lib/environment";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { helperContext } from "discourse/lib/helpers";
import { renderIcon } from "discourse/lib/icon-library";
import { SELECTORS } from "discourse/lib/lightbox/constants";
import {
  escapeExpression,
  postRNWebviewMessage,
} from "discourse/lib/utilities";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

export async function setupLightboxes({ container, selector }) {
  const lightboxService = getOwnerWithFallback(this).lookup("service:lightbox");
  lightboxService.setupLightboxes({ container, selector });
}

export function cleanupLightboxes() {
  const lightboxService = getOwnerWithFallback(this).lookup("service:lightbox");
  return lightboxService.cleanupLightboxes();
}

export async function loadMagnificPopup() {
  await waitForPromise(import("magnific-popup"));
}

export default async function lightbox(elem, siteSettings) {
  if (!elem) {
    return;
  }

  const lightboxes = elem.querySelectorAll(SELECTORS.DEFAULT_ITEM_SELECTOR);

  if (!lightboxes.length) {
    return;
  }

  const caps = helperContext().capabilities;
  const imageClickNavigation = caps.touch;

  await loadMagnificPopup();

  $(lightboxes).magnificPopup({
    type: "image",
    closeOnContentClick: false,
    removalDelay: isTesting() ? 0 : 300,
    mainClass: "mfp-zoom-in",
    tClose: i18n("lightbox.close"),
    tLoading: spinnerHTML,
    prependTo: isTesting() && document.getElementById("ember-testing"),

    gallery: {
      enabled: true,
      tPrev: i18n("lightbox.previous"),
      tNext: i18n("lightbox.next"),
      tCounter: i18n("lightbox.counter"),
      navigateByImgClick: imageClickNavigation,
    },

    ajax: {
      tError: i18n("lightbox.content_load_error"),
    },

    callbacks: {
      open() {
        if (!imageClickNavigation) {
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
        }

        if (caps.isAppWebview) {
          postRNWebviewMessage(
            "headerBg",
            $(".mfp-bg").css("background-color")
          );
        }
      },
      change() {
        this.wrap.removeClass("mfp-force-scrollbars");
      },
      beforeClose() {
        this.wrap.off("click.pinhandler");
        this.wrap.removeClass("mfp-force-scrollbars");
        if (caps.isAppWebview) {
          postRNWebviewMessage(
            "headerBg",
            $(".d-header").css("background-color")
          );
        }
      },
    },

    image: {
      tError: i18n("lightbox.image_load_error"),
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
              i18n("lightbox.download") +
              "</a>"
          );
        }
        src.push(
          '<a class="image-source-link" href="' +
            item.src +
            '">' +
            renderIcon("string", "image") +
            i18n("lightbox.open") +
            "</a>"
        );
        return src.join(" &middot; ");
      },
    },
  });
}
