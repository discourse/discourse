import loadScript, { loadCSS } from "discourse/lib/load-script";
import { iconHTML } from "discourse-common/lib/icon-library";
import { isRTL } from "discourse/lib/text-direction";
import User from "discourse/models/user";

export default function (elem, siteSettings) {
  // Discourse defaults
  const LIGHTBOX_SELECTOR = "*:not(.spoiler):not(.spoiled) a.lightbox";
  const PRELOAD_COUNT = 10;
  const SHOW_DOWNLOAD_ICON =
    !siteSettings.prevent_anons_from_downloading_files || User.current();
  const NEXT_ICON = isRTL()
    ? iconHTML("chevron-left")
    : iconHTML("chevron-right");
  const PREV_ICON = isRTL()
    ? iconHTML("chevron-right")
    : iconHTML("chevron-left");

  // window.lightboxOptions is for theme extensibility, We fallback to the
  // defaults defined above
  const options = window.lightboxOptions || {
    selector: LIGHTBOX_SELECTOR,
    preload: PRELOAD_COUNT,
    nextHtml: NEXT_ICON,
    prevHtml: PREV_ICON,
    download: SHOW_DOWNLOAD_ICON,
  };

  // main lib
  loadScript("/javascripts/light-gallery/lightgallery.min.js").then(() => {
    // lib zoom module
    loadScript("/javascripts/light-gallery/lg-zoom.min.js").then(() => {
      // lib base css
      loadCSS("/javascripts/light-gallery/lightgallery.min.css").then(() => {
        // eslint-disable-next-line
        lightGallery(elem, options);
      });
    });
  });
}
