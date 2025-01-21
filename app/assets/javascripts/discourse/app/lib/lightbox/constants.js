import { isTesting } from "discourse/lib/environment";

export const ANIMATION_DURATION =
  isTesting() || window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ? 0
    : 150;

export const MIN_CAROUSEL_ITEM_COUNT = 2;
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
  LIGHTBOX_CONTAINER: ".d-lightbox",
  LIGHTBOX_CONTENT: ".d-lightbox__content",
  LIGHTBOX_BODY: ".d-lightbox__body",
  FOCUS_TRAP: ".d-lightbox__focus-trap",
  MAIN_IMAGE: ".d-lightbox__main-image",
  MULTI_BUTTONS: ".d-lightbox__multi-item-controls",
  CAROUSEL_BUTTON: ".d-lightbox__carousel-button",
  PREV_BUTTON: ".d-lightbox__previous-button",
  NEXT_BUTTON: ".d-lightbox__next-button",
  CLOSE_BUTTON: ".d-lightbox__close-button",
  FULL_SCREEN_BUTTON: ".d-lightbox__full-screen-button",
  TAB_BUTTON: ".d-lightbox__new-tab-button",
  ROTATE_BUTTON: ".d-lightbox__rotate-button",
  ZOOM_BUTTON: ".d-lightbox__zoom-button",
  DOWNLOAD_BUTTON: ".d-lightbox__download-button",
  COUNTERS: ".d-lightbox__counters",
  COUNTER_CURRENT: ".d-lightbox__counter-current",
  COUNTER_TOTAL: ".d-lightbox__counter-total",
  IMAGE_TITLE: ".d-lightbox__image-title",
  ACTIVE_ITEM_TITLE: ".d-lightbox__item-title",
  ACTIVE_ITEM_FILE_DETAILS: ".d-lightbox__item-file-details",
  CAROUSEL: ".d-lightbox__carousel",
  CAROUSEL_ITEM: ".d-lightbox__carousel-item",
  CAROUSEL_PREV_BUTTON: ".d-lightbox__carousel-previous-button",
  CAROUSEL_NEXT_BUTTON: ".d-lightbox__carousel-next-button",
};

export const LIGHTBOX_APP_EVENT_NAMES = {
  CLEAN: "dom:clean",
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
