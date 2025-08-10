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

export default function lightbox(elem, siteSettings) {
  if (!elem) {
    return;
  }

  const lightboxes = elem.querySelectorAll(SELECTORS.DEFAULT_ITEM_SELECTOR);

  if (!lightboxes.length) {
    return;
  }

  const caps = helperContext().capabilities;
  const imageClickNavigation = caps.touch;

  (async () => {
    const [{ default: PhotoSwipeLightbox }, { default: PhotoSwipe }] =
      await Promise.all([import("photoswipe/lightbox"), import("photoswipe")]);

    const pswpLightbox = new PhotoSwipeLightbox({
      gallery: elem,
      children: SELECTORS.DEFAULT_ITEM_SELECTOR,
      pswpModule: PhotoSwipe,
      paddingFn: () => 0,
      wheelToZoom: !imageClickNavigation,
      initialZoomLevel: "fit",
      zoom: true,
      bgOpacity: isTesting() ? 1 : 0.7,
    });

    pswpLightbox.addFilter("itemData", (itemData) => {
      const anchor = itemData.element;
      const downloadHref = anchor?.dataset?.downloadHref;
      const infoText = anchor?.querySelector("span.informations")?.textContent;
      const title = anchor?.getAttribute("title") || "";

      // use the image dimensions if available on <img>
      const img = anchor?.querySelector("img");
      if (img) {
        const width = parseInt(img.getAttribute("width"), 10);
        const height = parseInt(img.getAttribute("height"), 10);
        if (width && height) {
          itemData.w = width;
          itemData.h = height;
        }
      }

      // Build caption HTML similar to previous implementation
      const parts = [escapeExpression(title)];
      if (infoText) {
        parts.push(infoText);
      }
      if (
        !siteSettings.prevent_anons_from_downloading_files ||
        User.current()
      ) {
        if (downloadHref) {
          parts.push(
            '<a class="image-source-link" href="' +
              downloadHref +
              '">' +
              renderIcon("string", "download") +
              i18n("lightbox.download") +
              "</a>"
          );
        }
      }
      parts.push(
        '<a class="image-source-link" href="' +
          itemData.src +
          '">' +
          renderIcon("string", "image") +
          i18n("lightbox.open") +
          "</a>"
      );

      itemData.caption = parts.join(" &middot; ");
      return itemData;
    });

    pswpLightbox.on("open", () => {
      if (caps.isAppWebview) {
        // PhotoSwipe uses a single root element with background via CSS
        postRNWebviewMessage(
          "headerBg",
          getComputedStyle(document.body).backgroundColor
        );
      }
      // keep reference for cleanup
      // store reference for route change cleanup
      window.__discoursePswpLightbox = pswpLightbox;
    });

    pswpLightbox.on("close", () => {
      if (caps.isAppWebview) {
        postRNWebviewMessage(
          "headerBg",
          getComputedStyle(document.querySelector(".d-header")).backgroundColor
        );
      }
      window.__discoursePswpLightbox = null;
    });

    pswpLightbox.init();
  })();
}
