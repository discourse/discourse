import { isTesting } from "discourse-common/config/environment";

export const ANIMATION_DURATION =
  isTesting() || window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ? 0
    : 150;

export const MIN_CAROUSEL_ARROW_ITEM_COUNT = 5;

export const SWIPE_THRESHOLD = 50;

export const SWIPE_DIRECTIONS = {
  DOWN: "down",
  LEFT: "left",
  RIGHT: "right",
  UP: "up",
};

export const DOCUMENT_ELEMENT_LIGHTBOX_OPEN_CLASS = "has-lightbox";
export const LIGHTBOX_ELEMENT_ID = "discourse-lightbox";
export const TITLE_ELEMENT_ID = "d-lightbox-image-title";

export const SELECTORS = {
  ACTIVE_CAROUSEL_ITEM: "[data-lightbox-carousel-item='current']",
  DEFAULT_ITEM_SELECTOR: "*:not(.spoiler):not(.spoiled) a.lightbox",
  FILE_DETAILS_CONTAINER: ".informations",
};

export const LIGHTBOX_APP_EVENT_NAMES = {
  // this cannot use dom:clean else #cleanupLightboxes will be called after #setupLighboxes
  CLEAN: "lightbox:clean",
  CLOSE: "lightbox:close",
  CLOSED: "lightbox:closed",
  ITEM_DID_CHANGE: "lightbox:item-did-change",
  ITEM_WILL_CHANGE: "lightbox:item-will-change",
  OPEN: "lightbox:open",
  OPENED: "lightbox:opened",
};

export const LAYOUT_TYPES = {
  HORIZONTAL: "horizontal",
  VERTICAL: "vertical",
};

export const KEYBOARD_SHORTCUTS = {
  CAROUSEL: "a",
  CLOSE: "Escape",
  DOWNLOAD: "d",
  FULLSCREEN: "m",
  NEWTAB: "n",
  NEXT: ["ArrowRight", "ArrowDown"],
  PREVIOUS: ["ArrowLeft", "ArrowUp"],
  ROTATE: "r",
  TITLE: "t",
  ZOOM: "z",
};
