import loadScript, { loadCSS } from "discourse/lib/load-script";
import { iconHTML } from "discourse-common/lib/icon-library";
import User from "discourse/models/user";

export default function (elem, siteSettings) {
  const isRTL = document.querySelector("html").classList.contains("rtl");

  const options = {
    mode: "lg-fade",
    startClass: "", // prevents default zoom transition
    selector: "*:not(.spoiler):not(.spoiled) a.lightbox",
    preload: 3, // how many extra images to preload when opened
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
        // eslint-disable-next-line
        lightGallery(elem, options);
      });
    });
  });
}
