import { scheduleOnce } from "@ember/runloop";
import loadScript, { loadCSS } from "discourse/lib/load-script";
import { iconHTML } from "discourse-common/lib/icon-library";
import User from "discourse/models/user";

const LIGHTBOX_SELECTOR = "*:not(.spoiler):not(.spoiled) a.lightbox";

export default function (elem, siteSettings) {
  if (!elem) {
    return;
  }

  const hasLightboxes = elem.querySelectorAll(LIGHTBOX_SELECTOR).length;

  if (hasLightboxes) {
    const isRTL = document.querySelector("html").classList.contains("rtl");

    const options = {
      mode: "lg-fade",
      startClass: "", // prevents default zoom transition
      selector: LIGHTBOX_SELECTOR,
      nextHtml: isRTL ? iconHTML("chevron-left") : iconHTML("chevron-right"),
      prevHtml: isRTL ? iconHTML("chevron-right") : iconHTML("chevron-left"),
      download:
        !siteSettings.prevent_anons_from_downloading_files || User.current(),
    };

    // main lib
    loadScript("/javascripts/light-gallery/lightgallery.min.js").then(() => {
      // lib zoom module
      loadScript("/javascripts/light-gallery/lg-zoom.min.js").then(() => {
        // lib base css
        loadCSS("/javascripts/light-gallery/lightgallery.min.css").then(() => {
          scheduleOnce("afterRender", this, () => {
            // eslint-disable-next-line
            lightGallery(elem, options);
          });
        });
      });
    });
  }
}
