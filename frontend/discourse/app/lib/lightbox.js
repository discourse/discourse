import { waitForPromise } from "@ember/test-waiters";
import $ from "jquery";
import { spinnerHTML } from "discourse/helpers/loading-spinner";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { helperContext } from "discourse/lib/helpers";
import { renderIcon } from "discourse/lib/icon-library";
import { SELECTORS } from "discourse/lib/lightbox/constants";
import { isDocumentRTL } from "discourse/lib/text-direction";
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

  const caps = helperContext().capabilities;
  const imageClickNavigation = caps.touch;
  const canDownload =
    !siteSettings.prevent_anons_from_downloading_files || User.current();

  if (siteSettings.experimental_lightbox) {
    const { default: PhotoSwipeLightbox } = await import("photoswipe/lightbox");
    const isTestEnv = isTesting() || isRailsTesting();

    const rtl = isDocumentRTL();
    const items = [...elem.querySelectorAll(SELECTORS.DEFAULT_ITEM_SELECTOR)];

    if (rtl) {
      items.reverse();
    }

    items.forEach((el, index) => {
      el.addEventListener("click", (e) => {
        e.preventDefault();

        lightboxEl.loadAndOpen(index);
      });
    });

    const lightboxEl = new PhotoSwipeLightbox({
      dataSource: items,
      arrowPrevTitle: i18n("lightbox.previous"),
      arrowNextTitle: i18n("lightbox.next"),
      closeTitle: i18n("lightbox.close"),
      zoomTitle: i18n("lightbox.zoom"),
      errorMsg: i18n("lightbox.error"),
      showHideAnimationType: isTestEnv ? "none" : "zoom",
      counter: false,
      tapAction,
      paddingFn,
      pswpModule: async () => await import("photoswipe"),
      appendToEl: isTesting() && document.getElementById("ember-testing"),
    });

    lightboxEl.on("afterInit", () => {
      const el = lightboxEl.pswp.currSlide.data.element;
      el.querySelector(".meta")?.classList.add("open");
    });

    lightboxEl.on("close", function () {
      lightboxEl.pswp.element.classList.add("pswp--behind-header");
    });

    lightboxEl.on("destroy", () => {
      const el = lightboxEl.pswp.currSlide.data.element;
      el.querySelector(".meta")?.classList.remove("open");
    });

    lightboxEl.on("uiRegister", function () {
      // adds a custom caption to lightbox
      lightboxEl.pswp.ui.registerElement({
        name: "caption",
        order: 11,
        isButton: false,
        appendTo: "root",
        html: "",
        onInit: (caption, pswp) => {
          pswp.on("change", () => {
            const { element, title, inlineSVG } = pswp.currSlide.data;

            if (!element || !title || inlineSVG) {
              return;
            }

            const captionTitle = escapeExpression(title);
            const captionDetails =
              element.querySelector(".informations")?.textContent;
            const titleEl = captionTitle
              ? `<div class='pswp__caption-title'>${captionTitle}</div>`
              : null;
            const detailsEl = captionDetails
              ? `<div class='pswp__caption-details'>${captionDetails}</div>`
              : null;

            caption.innerHTML = [titleEl, detailsEl].filter(Boolean).join("");
          });
        },
      });

      // adds a download button
      if (canDownload) {
        lightboxEl.pswp.ui.registerElement({
          name: "download-image",
          order: 7,
          isButton: true,
          tagName: "a",
          title: i18n("lightbox.download"),
          html: {
            isCustomSVG: true,
            inner:
              '<path d="M20.5 14.3 17.1 18V10h-2.2v7.9l-3.4-3.6L10 16l6 6.1 6-6.1ZM23 23H9v2h14Z" id="pswp__icn-download"/>',
            outlineID: "pswp__icn-download",
          },
          onInit: (el, pswp) => {
            el.setAttribute("download", "");
            el.setAttribute("target", "_blank");
            el.setAttribute("rel", "noopener");

            pswp.on("change", () => {
              const href = pswp.currSlide.data.element.dataset.downloadHref;
              if (!href) {
                el.style.display = "none";
                return;
              }
              el.href = href;
            });
          },
        });
      }

      // adds a view original image button
      lightboxEl.pswp.ui.registerElement({
        name: "original-image",
        order: 8,
        isButton: true,
        tagName: "a",
        title: i18n("lightbox.open"),
        html: {
          isCustomSVG: true,
          inner:
            '<path id="pswp__icn-image" d="M8 4C6.23 4 4.8 5.43 4.8 7.2v17.6c0 1.77 1.43 3.2 3.2 3.2h17.6c1.77 0 3.2-1.43 3.2-3.2V7.2c0-1.77-1.43-3.2-3.2-3.2H8zm2.56 4C11.6 8 12.8 9.2 12.8 10.8s-1.2 2.8-2.8 2.8-2.8-1.2-2.8-2.8S9.04 8 10.56 8zm7.2 4.48c0.42 0 0.84 0.21 1.1 0.56l5.44 8.72c0.28 0.46 0.29 1.04 0.03 1.52s-0.74 0.72-1.28 0.72H9.2a1.36 1.36 0 0 1-1.3-0.88c-0.26-0.52-0.22-1.12 0.12-1.6l3.12-4.64c0.28-0.4 0.74-0.64 1.24-0.64s0.96 0.24 1.24 0.64l1.64 2.32 3.76-6.16a1.28 1.28 0 0 1 1.1-0.56z"/>',
          outlineID: "pswp__icn-image",
        },
        onInit: (el, pswp) => {
          el.setAttribute("target", "_blank");
          el.setAttribute("rel", "noopener");

          pswp.on("change", () => {
            el.href = pswp.currSlide.data.src;
          });
        },
      });

      lightboxEl.pswp.ui.registerElement({
        name: "image-info",
        order: 9,
        isButton: true,
        tagName: "a",
        title: i18n("lightbox.image_info"),
        html: {
          isCustomSVG: true,
          inner:
            '<path id="pswp__icn-info" d="M16 28.8C23.07 28.8 28.8 23.07 28.8 16C28.8 8.93 23.07 3.2 16 3.2C8.93 3.2 3.2 8.93 3.2 16C3.2 23.07 8.93 28.8 16 28.8zM14.4 11.2C14.4 10.31 15.115 9.6 16 9.6C16.88 9.6 17.6 10.315 17.6 11.2C17.6 12.085 16.885 12.8 16 12.8C15.115 12.8 14.4 12.085 14.4 11.2zM14 14.4L16.4 14.4C17.065 14.4 17.6 14.935 17.6 15.6L17.6 20L18 20C18.665 20 19.2 20.535 19.2 21.2C19.2 21.865 18.665 22.4 18 22.4L14 22.4C13.335 22.4 12.8 21.865 12.8 21.2C12.8 20.535 13.335 20 14 20L15.2 20L15.2 16.8L14 16.8C13.335 16.8 12.8 16.265 12.8 15.6C12.8 14.935 13.335 14.4 14 14.4z"/>',
          outlineID: "pswp__icn-info",
        },
        onInit: (el, pswp) => {
          pswp.on("change", () => {
            el.style.display = pswp.currSlide.data.details ? "block" : "none";
          });
        },
        onClick: () => {
          lightboxEl.pswp.element.classList.toggle("pswp--caption-expanded");
        },
      });

      lightboxEl.pswp.ui.registerElement({
        name: "custom-counter",
        order: 6,
        isButton: false,
        appendTo: "bar",
        onInit: (el, pswp) => {
          pswp.on("change", () => {
            const total = pswp.getNumItems();
            const index = rtl ? total - pswp.currIndex : pswp.currIndex + 1;
            el.textContent = `${index} / ${total}`;
          });
        },
      });
    });

    lightboxEl.addFilter("itemData", (data) => {
      const el = data.element;

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

      const imgInfo = el.querySelector(".informations")?.textContent || "";

      if (!width || !height) {
        const dimensions = imgInfo.trim().split(" ")[0];
        [width, height] = dimensions.split(/x|×/).map(Number);
      }

      // this ensures that cropped images (eg: grid) do not cause jittering when closing
      data.thumbCropped = true;

      data.src = data.src || el.getAttribute("data-large-src");
      data.title = el.title || el.alt;
      data.details = imgInfo;
      data.w = data.width = width;
      data.h = data.height = height;

      return data;
    });

    // Preload images without dimensions to get their dimensions
    const itemsToPreload = Array.from(
      elem.querySelectorAll(SELECTORS.DEFAULT_ITEM_SELECTOR)
    ).filter((item) => {
      // Check if item has an image source
      const hasImageSrc =
        item.getAttribute("data-large-src") || item.getAttribute("href");

      // Check if dimensions are missing
      const missingDimensions =
        !item.getAttribute("data-target-width") ||
        !item.getAttribute("data-target-height");

      // Only preload if it has an image AND is missing dimensions
      return hasImageSrc && missingDimensions;
    });

    await Promise.all(
      itemsToPreload.map(
        (item) =>
          new Promise((resolve) => {
            const img = new Image();
            img.src =
              item.getAttribute("data-large-src") || item.getAttribute("href");
            img.onload = () => {
              item.setAttribute("data-target-width", img.naturalWidth);
              item.setAttribute("data-target-height", img.naturalHeight);
              resolve();
            };
            img.onerror = resolve;
          })
      )
    );
    function tapAction(pt, event) {
      const pswp = lightboxEl.pswp;
      if (event.target.classList.contains("pswp__img")) {
        pswp?.element?.classList.toggle("pswp--ui-visible");
      } else {
        pswp?.close();
      }
    }

    function paddingFn(viewportSize, itemData) {
      if (viewportSize.x < 1200 || caps.isMobileDevice) {
        return { top: 0, bottom: 0, left: 0, right: 0 };
      }
      return {
        top: 20,
        bottom: itemData.title ? 75 : 20,
        left: 20,
        right: 20,
      };
    }

    lightboxEl.init();
  } else {
    // Magnific lightbox
    const images = elem.querySelectorAll(SELECTORS.DEFAULT_ITEM_SELECTOR);

    if (!images.length) {
      return;
    }

    await loadMagnificPopup();

    $(images).magnificPopup({
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

          if (canDownload) {
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
