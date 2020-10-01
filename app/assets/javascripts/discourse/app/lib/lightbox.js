import loadScript, { loadCSS } from "discourse/lib/load-script";
import { iconHTML } from "discourse-common/lib/icon-library";
import { isRTL } from "discourse/lib/text-direction";
import User from "discourse/models/user";

const LIGHTBOX_SELECTOR = "*:not(.spoiler):not(.spoiled) a.lightbox";
const NEXT_ICON = isRTL()
  ? iconHTML("chevron-left")
  : iconHTML("chevron-right");
const PREV_ICON = isRTL()
  ? iconHTML("chevron-right")
  : iconHTML("chevron-left");
const PRELOAD_COUNT = 10;

export default function (elem, siteSettings) {
  if (!elem) {
    return;
  }

  const showDownloadIcon =
    !siteSettings.prevent_anons_from_downloading_files || User.current();

  // main lib
  loadScript("/javascripts/light-gallery/lightgallery.min.js").then(() => {
    // lib zoom module
    loadScript("/javascripts/light-gallery/lg-zoom.min.js").then(() => {
      // lib base css
      loadCSS("/javascripts/light-gallery/lightgallery.min.css").then(() => {
        // eslint-disable-next-line
        lightGallery(elem, {
          mode: "lg-fade", // default is ugly
          startClass: "", // default is ugly
          selector: LIGHTBOX_SELECTOR,
          preload: PRELOAD_COUNT,
          nextHtml: NEXT_ICON,
          prevHtml: PREV_ICON,
          enableDrag: false, // no support for RTL for now
          download: showDownloadIcon,
        });
      });
    });
  });
}
