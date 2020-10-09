import { schedule } from "@ember/runloop";
import loadScript, { loadCSS } from "discourse/lib/load-script";
import { iconHTML } from "discourse-common/lib/icon-library";
import User from "discourse/models/user";

// TODO: move this function to a helper
const getScrollbarWidth = () => {
  const outer = document.createElement("div");
  outer.style.visibility = "hidden";
  outer.style.overflow = "scroll";
  document.body.appendChild(outer);

  const inner = document.createElement("div");
  outer.appendChild(inner);

  const scrollbarWidth = outer.offsetWidth - inner.offsetWidth;
  outer.parentNode.removeChild(outer);

  return scrollbarWidth;
};

const docElement = document.querySelector("html");
const isRTL = docElement.classList.contains("rtl");

const LIGHTBOX_SELECTOR = "*:not(.spoiler):not(.spoiled) a.lightbox";
const NEXT_ICON = isRTL ? iconHTML("chevron-left") : iconHTML("chevron-right");
const PREV_ICON = isRTL ? iconHTML("chevron-right") : iconHTML("chevron-left");
const ANIMATION = "lg-fade";
const INITIAL_ANIMATION = "";
const HIDE_CONTROLS_DELAY = 3000;

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
            window.lgModules.translatableTitles = translatableTitles;

            // eslint-disable-next-line
            lightGallery(elem, options);
          });
        });
      });
    });
  }
}

// Discourse specific modules

// Module: translatable counter
// TODO: use YAML keys
const setTranslatableTitles = () => {
  const translations = {
    nextArrow: "next",
    prevArrow: "previous",
    zoomInIcon: "zoom in",
    zoomOutIcon: "zoom out",
    actualSizeIcon: "actual size",
    downloadIcon: "download",
    closeIcon: "close",
  };

  // gallery div
  const gd = docElement.querySelector(".lg-outer");

  const elements = {
    nextArrow: gd.querySelector(".lg-next"),
    prevArrow: gd.querySelector(".lg-prev"),
    zoomInIcon: gd.querySelector("#lg-zoom-in"),
    zoomOutIcon: gd.querySelector("#lg-zoom-out"),
    actualSizeIcon: gd.querySelector("#lg-actual-size"),
    downloadIcon: gd.querySelector(".lg-download"),
    closeIcon: gd.querySelector(".lg-close"),
  };

  for (const [key, value] of Object.entries(elements)) {
    if (value && translations[key]) {
      value.title = translations[key];
    }
  }
};

const translatableTitles = function (elem) {
  this.elem = elem;
  this.init();

  return this;
};

translatableTitles.prototype.init = function () {
  this.elem.addEventListener("onBeforeOpen", setTranslatableTitles, {
    passive: true,
  });
};

translatableTitles.prototype.destroy = function () {
  this.elem.removeEventListener("onBeforeOpen", setTranslatableTitles, {
    passive: true,
  });
};

// Module: remove HTML scrollbars when open

const addNoScrollClass = () => {
  docElement.style.setProperty("--scrollbar-width", getScrollbarWidth() + "px");
  docElement.classList.add("lg-open");
};

const removeNoScrollClass = () => {
  docElement.style.removeProperty("--scrollbar-width");
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
