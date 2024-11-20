import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import {
  DOCUMENT_ELEMENT_LIGHTBOX_OPEN_CLASS,
  LIGHTBOX_APP_EVENT_NAMES,
  MIN_CAROUSEL_ARROW_ITEM_COUNT,
  MIN_CAROUSEL_ITEM_COUNT,
  SELECTORS,
} from "discourse/lib/lightbox/constants";
import {
  getSiteThemeColor,
  setSiteThemeColor,
} from "discourse/lib/lightbox/helpers";
import { processHTML } from "discourse/lib/lightbox/process-html";
import { isDocumentRTL } from "discourse/lib/text-direction";
import { bind } from "discourse-common/utils/decorators";

@disableImplicitInjections
export default class LightboxService extends Service {
  @service appEvents;
  @service site;
  @service siteSettings;

  lightboxIsOpen = false;
  lightboxClickElements = [];
  lastFocusedElement = null;
  originalSiteThemeColor = null;
  onFocus = null;
  selector = null;

  callbacks = {};
  options = {};

  async init() {
    super.init(...arguments);

    this.callbacks = {
      onOpen: this.onLightboxOpened,
      onClose: this.onLightboxClosed,
      onWillChange: this.onLightboxItemWillChange,
      onItemDidChange: this.onLightboxItemDidChange,
      onCleanUp: this.onLightboxCleanedUp,
    };

    this.options = {
      isMobile: this.site.mobileView,
      isRTL: isDocumentRTL(),
      minCarouselItemCount: MIN_CAROUSEL_ITEM_COUNT,
      minCarouselArrowItemCount: MIN_CAROUSEL_ARROW_ITEM_COUNT,
      zoomOnOpen: false,
      canDownload:
        this.currentUser ||
        !this.siteSettings.prevent_anons_from_downloading_files,
    };

    this.appEvents.on(
      LIGHTBOX_APP_EVENT_NAMES.CLEAN,
      this,
      this.cleanupLightboxes
    );
  }

  willDestroy() {
    this.#reset();
  }

  @bind
  async onLightboxOpened({ items, currentItem }) {
    this.originalSiteThemeColor = await getSiteThemeColor();

    document.documentElement.classList.add(
      DOCUMENT_ELEMENT_LIGHTBOX_OPEN_CLASS
    );

    this.#setupDocumentFocus();

    this.appEvents.trigger(LIGHTBOX_APP_EVENT_NAMES.OPENED, {
      items,
      currentItem,
    });
  }

  @bind
  async onLightboxItemWillChange({ currentItem }) {
    this.appEvents.trigger(LIGHTBOX_APP_EVENT_NAMES.ITEM_WILL_CHANGE, {
      currentItem,
    });
  }

  @bind
  async onLightboxItemDidChange({ currentItem }) {
    this.appEvents.trigger(LIGHTBOX_APP_EVENT_NAMES.ITEM_DID_CHANGE, {
      currentItem,
    });
  }

  @bind
  async onLightboxClosed() {
    document.documentElement.classList.remove(
      DOCUMENT_ELEMENT_LIGHTBOX_OPEN_CLASS
    );

    setSiteThemeColor(this.originalSiteThemeColor);
    this.#restoreDocumentFocus();

    this.originalSiteThemeColor = "";
    this.lightboxIsOpen = false;

    this.appEvents.trigger(LIGHTBOX_APP_EVENT_NAMES.CLOSED);
  }

  @bind
  onLightboxCleanedUp() {
    return true;
  }

  @bind
  async openLightbox({ container, selector, clickTarget }) {
    const { items, startingIndex } = await processHTML({
      container,
      selector,
      clickTarget,
    });

    if (!items.length) {
      return;
    }

    this.appEvents.trigger(LIGHTBOX_APP_EVENT_NAMES.OPEN, {
      items,
      startingIndex,
      callbacks: { ...this.callbacks },
      options: { ...this.options },
    });

    this.lightboxIsOpen = true;
  }

  @bind
  async closeLightbox() {
    if (this.lightboxIsOpen) {
      this.appEvents.trigger(LIGHTBOX_APP_EVENT_NAMES.CLOSE);
      this.lightboxIsOpen = false;
    }
  }

  async #setupLightboxes({ container, selector }) {
    if (!container) {
      throw new Error("Lightboxes require a container to be passed in");
    }

    this.selector = selector;
    const hasLightboxes = container.querySelector(selector);

    if (!hasLightboxes) {
      return;
    }

    const handlerOptions = { capture: true };
    container.addEventListener(
      "click",
      (event) => {
        this.handleClickEvent(event, selector);
      },
      handlerOptions
    );

    this.lightboxClickElements.push({ container, handlerOptions });
  }

  @bind
  async setupLightboxes({ container, selector }) {
    this.#setupLightboxes({ container, selector });
  }

  async #cleanupLightboxes() {
    this.closeLightbox();

    this.lightboxClickElements.forEach(({ container, handlerOptions }) => {
      container.removeEventListener(
        "click",
        this.handleClickEvent,
        handlerOptions
      );
    });

    this.lightboxClickElements = [];
  }

  @bind
  async cleanupLightboxes() {
    this.#cleanupLightboxes();
  }

  async #setupDocumentFocus() {
    if (!this.lightboxIsOpen) {
      return;
    }

    this.lastFocusedElement = document.activeElement;
    document.activeElement.blur();
    document.querySelector(SELECTORS.CLOSE_BUTTON)?.focus();

    const focusableElements = document.querySelectorAll(
      SELECTORS.LIGHTBOX_CONTAINER + " button"
    );

    const firstFocusableElement = focusableElements[0];
    const lastFocusableElement =
      focusableElements[focusableElements.length - 1];

    const focusTraps = document.querySelectorAll(SELECTORS.FOCUS_TRAP);

    const firstfocusTrap = focusTraps[0];
    const lastfocusTrap = focusTraps[focusTraps.length - 1];

    this.onFocus = ({ target }) => {
      if (target === firstfocusTrap) {
        lastFocusableElement.focus();
      } else if (target === lastfocusTrap) {
        firstFocusableElement.focus();
      }
    };

    document.addEventListener("focus", this.onFocus, {
      passive: true,
      capture: true,
    });
  }

  async #restoreDocumentFocus() {
    document.removeEventListener("focus", this.onFocus, {
      passive: true,
      capture: true,
    });

    document.activeElement.blur();

    this.lastFocusedElement?.focus();
  }

  async #reset() {
    this.appEvents.off(
      LIGHTBOX_APP_EVENT_NAMES.CLEAN,
      this,
      this.cleanupLightboxes
    );
  }

  handleClickEvent(event, trigger) {
    const closestTrigger = event.target.closest(trigger);
    const isLightboxClick = event
      .composedPath()
      .find(
        (element) =>
          element.matches &&
          (element.matches(trigger) ||
            element.matches("[data-lightbox-trigger]"))
      );

    if (!isLightboxClick) {
      return;
    }

    event.preventDefault();

    this.openLightbox({
      container: event.currentTarget,
      selector: trigger,
      clickTarget: closestTrigger,
    });

    event.target.toggleAttribute(SELECTORS.DOCUMENT_LAST_FOCUSED_ELEMENT);
  }
}
