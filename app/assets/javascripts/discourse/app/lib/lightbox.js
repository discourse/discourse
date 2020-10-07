import { schedule } from "@ember/runloop";
import loadScript, { loadCSS } from "discourse/lib/load-script";
import { iconHTML } from "discourse-common/lib/icon-library";
import User from "discourse/models/user";

const docElement = document.querySelector("html");
const isRTL = docElement.classList.contains("rtl");

// which elements to show in the gallery
const LIGHTBOX_SELECTOR = "*:not(.spoiler):not(.spoiled) a.lightbox";
const NEXT_ICON = isRTL ? iconHTML("chevron-left") : iconHTML("chevron-right");
const PREV_ICON = isRTL ? iconHTML("chevron-right") : iconHTML("chevron-left");
const ANIMATION = "lg-fade";
const INITIAL_ANIMATION = "";
const HIDE_CONTROLS_DELAY = 3000; // hide controls after 3s

export default function (elem, siteSettings) {
  if (!elem) {
    return;
  }

  const hasLightboxes = elem.querySelectorAll(LIGHTBOX_SELECTOR).length;
  const canDownload =
    !siteSettings.prevent_anons_from_downloading_files || User.current();

  if (hasLightboxes) {
    const options = {
      mode: ANIMATION,
      startClass: INITIAL_ANIMATION, // prevents default zoom transition
      selector: LIGHTBOX_SELECTOR,
      hideBarsDelay: HIDE_CONTROLS_DELAY,
      nextHtml: NEXT_ICON,
      prevHtml: PREV_ICON,
      download: canDownload,
    };

    // main lib
    loadScript("/javascripts/lightgallery.min.js").then(() => {
      // lib zoom module
      loadScript("/javascripts/lg-zoom.min.js").then(() => {
        // lib base css
        loadCSS("/javascripts/lightgallery.min.css").then(() => {
          schedule("afterRender", this, () => {
            // add new Discourse specific modules here
            window.lgModules.removeWindowScrollbars = removeWindowScrollbars;
            // eslint-disable-next-line
            lightGallery(elem, options);
          });
        });
      });
    });
  }
}

// Discourse specific modules

// Module: remove HTML scrollbars when open
const addNoScrollClass = () => {
  docElement.classList.add("lg-open");
};

const removeNoScrollClass = () => {
  docElement.classList.remove("lg-open");
};

const removeWindowScrollbars = function (elem) {
  this.elem = elem;
  this.init();

  return this;
};

removeWindowScrollbars.prototype.init = function () {
  this.elem.addEventListener("onBeforeOpen", addNoScrollClass, {
    passive: true,
  });
  this.elem.addEventListener("onBeforeClose", removeNoScrollClass, {
    passive: true,
  });
};

removeWindowScrollbars.prototype.destroy = function () {
  this.elem.removeEventListener("onBeforeOpen", addNoScrollClass, {
    passive: true,
  });
  this.elem.removeEventListener("onBeforeClose", removeNoScrollClass, {
    passive: true,
  });
};
