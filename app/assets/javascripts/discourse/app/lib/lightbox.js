import PhotoSwipe from "photoswipe";
import PhotoSwipeLightbox from "photoswipe/lightbox";
import { renderIcon } from "discourse/lib/icon-library";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default function lightbox(elem, siteSettings) {
  if (!elem) {
    return;
  }

  const dlText = renderIcon("string", "download") + i18n("lightbox.download");
  const origImgText = renderIcon("string", "image") + i18n("lightbox.open");

  const lightboxEl = new PhotoSwipeLightbox({
    gallery: elem,
    children: ".lightbox",
    arrowPrevTitle: i18n("lightbox.previous"),
    arrowNextTitle: i18n("lightbox.next"),
    errorMsg: i18n("lightbox.content_load_error"),
    padding: { top: 20, bottom: 50, left: 20, right: 20 },
    pswpModule: () => PhotoSwipe,
  });

  lightboxEl.on("uiRegister", function () {
    const canDownload =
      !siteSettings.prevent_anons_from_downloading_files || User.current();

    lightboxEl.pswp.ui.registerElement({
      name: "caption",
      order: 9,
      isButton: false,
      appendTo: "root",
      html: "Caption text",
      onInit: (caption, pswp) => {
        pswp.on("change", () => {
          const slideEl = pswp.currSlide.data.element;
          let captionHTML = "";
          let title, download, details;

          if (slideEl) {
            const slideData = slideEl.dataset;
            const slideImg = slideEl.querySelector("img");
            const alt = slideEl.alt || slideImg?.getAttribute("alt");
            const info = slideEl.querySelector(".informations")?.innerText;
            const origSrc = slideData.largeSrc || slideEl.href || slideImg.src;
            const dlHref =
              slideData.downloadHref || slideData.largeSrc || slideImg.src;

            title = alt ? `<div class='title'>${alt}</div>` : null;
            details = info ? `<div class='details'>${info}</div>` : null;
            download = canDownload ? `<a href="${dlHref}">${dlText}</a>` : null;
            const origImg = `<a href="${origSrc}">${origImgText}</a>`;

            captionHTML = [title, details, download, origImg]
              .filter(Boolean)
              .join(" &middot; ");
          }

          caption.innerHTML = captionHTML;
        });
      },
    });
  });

  lightboxEl.addFilter("domItemData", (data, el) => {
    if (!el) {
      return data;
    }

    // if photoswipe data attributes are available then use those
    let width = el.getAttribute("data-pswp-width");
    let height = el.getAttribute("data-pswp-height");

    if (!width) {
      const imgInfo = el.querySelector(".informations")?.innerText;
      const imgSize = imgInfo.split(" ")[0].split("×");
      [width, height] = imgSize.map(Number);
    }

    data.src = data.src || el.getAttribute("data-large-src");
    data.w = data.width = width;
    data.h = data.height = height;

    return data;
  });

  lightboxEl.init();
}
