/**
 * @class FocusManagement
 * Manages focus behavior for sheets: auto-focus, scroll prevention, focusable lookup.
 */

/** @type {string} */
const FOCUSABLE_SELECTOR = [
  "input:not([disabled]):not([type=hidden])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "button:not([disabled])",
  "a[href]",
  "area[href]",
  "summary",
  "iframe",
  "object",
  "embed",
  "audio[controls]",
  "video[controls]",
  "[contenteditable]",
  "[tabindex]:not([disabled])",
].join(",");

/** @type {string} */
const SKIPPABLE_SELECTOR = [
  "[aria-hidden='true']",
  "[aria-hidden='true'] *",
  "[inert]",
  "[inert] *",
].join(",");

/**
 * @param {HTMLElement} element
 * @returns {boolean}
 */
function isElementVisible(element) {
  return !!(
    element.offsetWidth ||
    element.offsetHeight ||
    element.getClientRects().length
  );
}

/**
 * @param {HTMLElement} element
 * @returns {boolean}
 */
function isElementTabbable(element) {
  return element.matches(':not([hidden]):not([tabindex^="-"])');
}

/**
 * @param {HTMLElement} element
 * @returns {boolean}
 */
function isElementSkippable(element) {
  return element.matches(SKIPPABLE_SELECTOR) || !isElementVisible(element);
}

/**
 * @param {HTMLElement} container
 * @param {string[]} [additionalSkipSelectors]
 * @returns {{ safelyFocusableElements: HTMLElement[], safelyTabbableElements: HTMLElement[] }}
 */
function getFocusableElements(container, additionalSkipSelectors = []) {
  if (!container) {
    return { safelyFocusableElements: [], safelyTabbableElements: [] };
  }

  const selector = additionalSkipSelectors.length
    ? [FOCUSABLE_SELECTOR, ...additionalSkipSelectors].join(",")
    : FOCUSABLE_SELECTOR;

  const elements = [
    ...(container.matches(selector) ? [container] : []),
    ...container.querySelectorAll(selector),
  ];

  const elementsWithData = elements.map((element) => ({
    element,
    tabbable: isElementTabbable(element),
    skippable: isElementSkippable(element),
  }));

  const safelyFocusableElements = elementsWithData
    .filter((data) => !data.skippable)
    .map((data) => data.element);

  const safelyTabbableElements = elementsWithData
    .filter((data) => data.tabbable && !data.skippable)
    .map((data) => data.element);

  return { safelyFocusableElements, safelyTabbableElements };
}

/**
 * @param {Object} options
 * @param {Event|null} options.nativeEvent
 * @param {Object} options.defaultBehavior
 * @param {Function|Object} [options.handler]
 * @returns {Object}
 */
function processAutoFocusHandler({ nativeEvent, defaultBehavior, handler }) {
  let result = defaultBehavior;

  if (handler) {
    if (typeof handler === "function") {
      const event = {
        ...defaultBehavior,
        nativeEvent,
        changeDefault(changes) {
          result = { ...defaultBehavior, ...changes };
          Object.assign(this, changes);
        },
      };
      event.changeDefault = event.changeDefault.bind(event);
      handler(event);
    } else {
      result = { ...defaultBehavior, ...handler };
    }
  }

  return result;
}

export default class FocusManagement {
  /** @type {Object} */
  controller;

  /** @type {Function|null} */
  focusScrollPreventionListener = null;

  /** @type {HTMLElement|null} */
  previouslyFocusedElement = null;

  /**
   * @param {Object} controller
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * @returns {void}
   */
  capturePreviouslyFocusedElement() {
    if (typeof document !== "undefined") {
      this.previouslyFocusedElement = document.activeElement;
    }
  }

  /**
   * @returns {HTMLElement|null}
   */
  findAutoFocusTarget() {
    const view = this.controller.view;
    if (!view) {
      return null;
    }

    const { safelyFocusableElements, safelyTabbableElements } =
      getFocusableElements(view, ["[data-d-sheet-autofocus-skip]"]);

    const explicitTargets = view.querySelectorAll(
      "[data-d-sheet-autofocus-target]"
    );
    const safeExplicitTarget = Array.from(explicitTargets).find((target) =>
      safelyFocusableElements.includes(target)
    );

    if (safeExplicitTarget) {
      return safeExplicitTarget;
    }

    return safelyTabbableElements[0] ?? view;
  }

  /**
   * @returns {void}
   */
  executeAutoFocusOnPresent() {
    const behavior = processAutoFocusHandler({
      nativeEvent: null,
      defaultBehavior: { focus: true },
      handler: this.controller.onPresentAutoFocus,
    });

    if (behavior.focus === false) {
      return;
    }

    const target = this.findAutoFocusTarget();
    if (target) {
      target.focus({ preventScroll: true });
    }
  }

  /**
   * @returns {void}
   */
  executeAutoFocusOnDismiss() {
    const view = this.controller.view;
    const activeElement = document.activeElement;

    // Only restore focus if activeElement is inside view or was removed from document
    if (
      view &&
      !view.contains(activeElement) &&
      document.contains(activeElement)
    ) {
      this.previouslyFocusedElement = null;
      return;
    }

    const behavior = processAutoFocusHandler({
      nativeEvent: null,
      defaultBehavior: { focus: true },
      handler: this.controller.onDismissAutoFocus,
    });

    if (behavior.focus === false) {
      this.previouslyFocusedElement = null;
      return;
    }

    const target =
      this.previouslyFocusedElement &&
      document.contains(this.previouslyFocusedElement)
        ? this.previouslyFocusedElement
        : document.body;

    target.focus({ preventScroll: true });
    this.previouslyFocusedElement = null;
  }

  /**
   * @returns {void}
   */
  setupFocusScrollPrevention() {
    if (
      !this.controller.nativeFocusScrollPrevention ||
      !this.controller.view ||
      this.focusScrollPreventionListener ||
      typeof document === "undefined"
    ) {
      return;
    }

    this.focusScrollPreventionListener = (event) => {
      if (!this.controller.view?.contains(event.target)) {
        return;
      }

      const scrollContainer = this.controller.scrollContainer;
      if (!scrollContainer) {
        return;
      }

      const scrollTop = scrollContainer.scrollTop;
      const scrollLeft = scrollContainer.scrollLeft;

      requestAnimationFrame(() => {
        if (scrollContainer) {
          scrollContainer.scrollTop = scrollTop;
          scrollContainer.scrollLeft = scrollLeft;
        }
      });
    };

    this.controller.view.addEventListener(
      "focus",
      this.focusScrollPreventionListener,
      { capture: true }
    );
  }

  /**
   * @returns {void}
   */
  cleanupFocusScrollPrevention() {
    if (this.focusScrollPreventionListener && this.controller.view) {
      this.controller.view.removeEventListener(
        "focus",
        this.focusScrollPreventionListener,
        { capture: true }
      );
    }
    this.focusScrollPreventionListener = null;
  }

  /**
   * @returns {void}
   */
  cleanup() {
    this.cleanupFocusScrollPrevention();
    this.previouslyFocusedElement = null;
  }
}
