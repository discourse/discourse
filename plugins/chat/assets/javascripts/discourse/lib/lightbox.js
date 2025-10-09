import $ from "jquery";
import { spinnerHTML } from "discourse/helpers/loading-spinner";
import lightbox from "discourse/lib/lightbox";
import loadScript from "discourse/lib/load-script";
import { i18n } from "discourse-i18n";

export default function loadLightbox(element, siteSettings) {
  if (!element) {
    return;
  }

  if (siteSettings.experimental_lightbox) {
    lightbox(element, siteSettings);
    return;
  }

  const images = element?.querySelectorAll("img.chat-img-upload");

  if (!images.length) {
    return;
  }

  loadScript("/javascripts/jquery.magnific-popup.min.js").then(function () {
    $(images).magnificPopup({
      type: "image",
      closeOnContentClick: false,
      mainClass: "mfp-zoom-in",
      tClose: i18n("lightbox.close"),
      tLoading: spinnerHTML,
      image: {
        verticalFit: true,
      },
      gallery: {
        enabled: true,
      },
      callbacks: {
        elementParse: (item) => {
          item.src = item.el[0].dataset.largeSrc || item.el[0].src;
        },
        open: function () {
          this.touchActionValue = document.body.style.touchAction;
          document.body.style.touchAction = "";
        },
        close: function () {
          document.body.style.touchAction = this.touchActionValue;
        },
      },
    });
  });
}
