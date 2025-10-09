import { waitForPromise } from "@ember/test-waiters";
import $ from "jquery";
import { spinnerHTML } from "discourse/helpers/loading-spinner";
import { isTesting } from "discourse/lib/environment";
import { helperContext } from "discourse/lib/helpers";
import { renderIcon } from "discourse/lib/icon-library";
import { SELECTORS } from "discourse/lib/lightbox/constants";
import {
  escapeExpression,
  postRNWebviewMessage,
} from "discourse/lib/utilities";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

export async function loadMagnificPopup() {
  await waitForPromise(import("magnific-popup"));
}

export default async function lightbox(elem, siteSettings) {
  if (!elem) {
    return;
  }

  if (siteSettings.experimental_lightbox) {
    const { default: PhotoSwipeLightbox } = await import("photoswipe/lightbox");

    const lightboxEl = new PhotoSwipeLightbox({
      gallery: elem,
      children: SELECTORS.DEFAULT_ITEM_SELECTOR,
      arrowPrevTitle: i18n("lightbox.previous"),
      arrowNextTitle: i18n("lightbox.next"),
      errorMsg: i18n("lightbox.content_load_error", { url: elem.href }),
      pswpModule: async () => await import("photoswipe"),
    });

    // adds a custom caption to lightbox
    lightboxEl.on("uiRegister", function () {
      lightboxEl.pswp.ui.registerElement({
        name: "caption",
        order: 7,
        isButton: false,
        appendTo: "root",
        html: "",
        onInit: (caption, pswp) => {
          pswp.on("change", () => {
            const { element, isChat, inlineSVG } = pswp.currSlide.data;

            if (!element || isChat || inlineSVG) {
              return;
            }

            const text = escapeExpression(element.alt || element.title);
            const info = element.querySelector(".informations")?.innerText;
            const title = text ? `<div class='title'>${text}</div>` : null;
            const details = info ? `<div class='details'>${info}</div>` : null;

            caption.innerHTML = [title, details].filter(Boolean).join("");
          });
        },
      });

      lightboxEl.pswp.ui.registerElement({
        name: "download-image",
        order: 8,
        isButton: true,
        tagName: "a",
        title: i18n("lightbox.download"),
        html: renderIcon("string", "download"),

        onInit: (el, pswp) => {
          if (
            siteSettings.prevent_anons_from_downloading_files ||
            !User.current()
          ) {
            return false;
          }

          el.setAttribute("target", "_blank");
          el.setAttribute("rel", "noopener");

          pswp.on("change", () => {
            el.href = pswp.currSlide.data.element.dataset.downloadHref;
          });
        },
      });

      lightboxEl.pswp.ui.registerElement({
        name: "original-image",
        order: 9,
        isButton: true,
        tagName: "a",
        title: i18n("lightbox.open"),
        html: renderIcon("string", "image"),

        onInit: (el, pswp) => {
          el.setAttribute("target", "_blank");
          el.setAttribute("rel", "noopener");

          pswp.on("change", () => {
            el.href = pswp.currSlide.data.src;
          });
        },
      });
    });

    lightboxEl.addFilter("domItemData", (data, el) => {
      if (!el) {
        return data;
      }

      // use data attributes for width/height when available
      let width = el.getAttribute("data-target-width");
      let height = el.getAttribute("data-target-height");
      const isSVG = el.querySelector("svg[viewBox]") !== null;

      if (isSVG) {
        const encodedSVG = encodeURIComponent(el.innerHTML.trim());
        data.src = `data:image/svg+xml,${encodedSVG}`;
        data.inlineSVG = true;
        width = (el.clientWidth || 400) * 10;
        height = (el.clientHeight || 300) * 10;

        // 1x1 placeholder to prevent background flicker on inline SVGs
        data.msrc =
          "data:image/svg+xml,%3Csvg%20xmlns%3D%27http%3A//www.w3.org/2000/svg%27%20width%3D%271%27%20height%3D%271%27/%3E";
      }

      if (!width || !height) {
        const imgInfo = el.querySelector(".informations")?.innerText || "";

        if (imgInfo?.includes("×")) {
          const imgSize = imgInfo.split(" ")[0].split("×");
          [width, height] = imgSize.map(Number);
        }
      }

      data.src = data.src || el.getAttribute("data-large-src");
      data.isChat = el.classList.contains("chat-img-upload");
      data.w = data.width = width;
      data.h = data.height = height;

      return data;
    });

    lightboxEl.init();
  } else {
    // Magnific lightbox
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
          const downloadText =
            renderIcon("string", "download") + i18n("lightbox.download");
          const origImgText =
            renderIcon("string", "image") + i18n("lightbox.open");

          let src = [
            escapeExpression(item.el.attr("title")),
            $("span.informations", item.el).text(),
          ];

          if (
            !siteSettings.prevent_anons_from_downloading_files ||
            User.current()
          ) {
            src.push(
              `<a class="image-source-link" href="${href}">${downloadText}</a>`
            );
          }
          src.push(
            `<a class="image-source-link" href="${item.src}">${origImgText}</a>`
          );
          return src.join(" &middot; ");
        },
      },
    });
  }
}
