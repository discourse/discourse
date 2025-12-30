import { processBehavior } from "discourse/float-kit/lib/behavior-handler";

/**
 * Selector for focusable elements.
 *
 * @type {string}
 */
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

/**
 * Selectors for elements that should be skipped during focus traversal.
 *
 * @type {string[]}
 */
const SKIPPABLE_SELECTORS = [
  "[aria-hidden='true']",
  "[aria-hidden='true'] *",
  "[inert]",
  "[inert] *",
];

/**
 * Data attribute for elements to skip during auto-focus.
 *
 * @type {string}
 */
const AUTOFOCUS_SKIP_SELECTOR = "[data-d-sheet-autofocus-skip]";

/**
 * Data attribute for explicit auto-focus targets.
 *
 * @type {string}
 */
const AUTOFOCUS_TARGET_SELECTOR = "[data-d-sheet-autofocus-target]";

/**
 * Get focusable and tabbable elements within a container.
 *
 * @param {HTMLElement} container - The container element to search within
 * @param {string[]} [additionalSkipSelectors] - Additional selectors for elements to skip
 * @returns {{ safelyFocusableElements: HTMLElement[], safelyTabbableElements: HTMLElement[] }}
 */
function getFocusableElements(container, additionalSkipSelectors = []) {
  if (!container) {
    return { safelyFocusableElements: [], safelyTabbableElements: [] };
  }

  const selector = additionalSkipSelectors.length
    ? [FOCUSABLE_SELECTOR, ...additionalSkipSelectors].join(",")
    : FOCUSABLE_SELECTOR;

  const skipSelector = [
    ...additionalSkipSelectors,
    ...SKIPPABLE_SELECTORS,
  ].join(",");

  const elements = [
    ...(container.matches(selector) ? [container] : []),
    ...container.querySelectorAll(selector),
  ];

  const elementsWithData = elements.map((element) => ({
    element,
    tabbable: element.matches(':not([hidden]):not([tabindex^="-"])'),
    skippable:
      element.matches(skipSelector) ||
      !(
        element.offsetWidth ||
        element.offsetHeight ||
        element.getClientRects().length
      ),
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
 * Manages focus behavior for sheets including auto-focus on present/dismiss
 * and scroll prevention during focus changes.
 *
 * @class FocusManagement
 */
export default class FocusManagement {
  /**
   * The sheet controller instance.
   *
   * @type {Object}
   */
  controller;

  /**
   * Listener for focus scroll prevention.
   *
   * @type {Function|null}
   */
  #focusScrollPreventionListener = null;

  /**
   * The element that was focused before the sheet opened.
   *
   * @type {HTMLElement|null}
   */
  #previouslyFocusedElement = null;

  /**
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Get the view element from controller.
   *
   * @returns {HTMLElement|null}
   */
  get #view() {
    return this.controller.view;
  }

  /**
   * Get the scroll container element from controller.
   *
   * @returns {HTMLElement|null}
   */
  get #scrollContainer() {
    return this.controller.scrollContainer;
  }

  /**
   * Capture the currently focused element before the sheet opens.
   */
  capturePreviouslyFocusedElement() {
    if (typeof document !== "undefined") {
      this.#previouslyFocusedElement = document.activeElement;
    }
  }

  /**
   * Find the appropriate element to auto-focus when the sheet is presented.
   *
   * @returns {HTMLElement|null}
   */
  findAutoFocusTarget() {
    if (!this.#view) {
      return null;
    }

    const { safelyFocusableElements, safelyTabbableElements } =
      getFocusableElements(this.#view, [AUTOFOCUS_SKIP_SELECTOR]);

    const explicitTargets = this.#view.querySelectorAll(
      AUTOFOCUS_TARGET_SELECTOR
    );
    const safeExplicitTarget = Array.from(explicitTargets).find((target) =>
      safelyFocusableElements.includes(target)
    );

    if (safeExplicitTarget) {
      return safeExplicitTarget;
    }

    return safelyTabbableElements[0] ?? this.#view;
  }

  /**
   * Execute auto-focus when the sheet is presented.
   */
  executeAutoFocusOnPresent() {
    const behavior = processBehavior({
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
   * Execute auto-focus when the sheet is dismissed.
   * Restores focus to the previously focused element if appropriate.
   */
  executeAutoFocusOnDismiss() {
    const activeElement = document.activeElement;

    if (
      this.#view &&
      !this.#view.contains(activeElement) &&
      document.contains(activeElement)
    ) {
      this.#previouslyFocusedElement = null;
      return;
    }

    const behavior = processBehavior({
      nativeEvent: null,
      defaultBehavior: { focus: true },
      handler: this.controller.onDismissAutoFocus,
    });

    if (behavior.focus === false) {
      this.#previouslyFocusedElement = null;
      return;
    }

    const target =
      this.#previouslyFocusedElement &&
      document.contains(this.#previouslyFocusedElement)
        ? this.#previouslyFocusedElement
        : document.body;

    target.focus({ preventScroll: true });
    this.#previouslyFocusedElement = null;
  }

  /**
   * Set up focus scroll prevention listener on the view.
   * Prevents scroll container from scrolling when focus changes within the sheet.
   */
  setupFocusScrollPrevention() {
    if (
      !this.controller.nativeFocusScrollPrevention ||
      !this.#view ||
      this.#focusScrollPreventionListener ||
      typeof document === "undefined"
    ) {
      return;
    }

    this.#focusScrollPreventionListener = (event) => {
      if (!this.#view?.contains(event.target)) {
        return;
      }

      const scrollContainer = this.#scrollContainer;
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

    this.#view.addEventListener("focus", this.#focusScrollPreventionListener, {
      capture: true,
    });
  }

  /**
   * Clean up focus scroll prevention listener.
   */
  #cleanupFocusScrollPrevention() {
    if (this.#focusScrollPreventionListener && this.#view) {
      this.#view.removeEventListener(
        "focus",
        this.#focusScrollPreventionListener,
        { capture: true }
      );
    }
    this.#focusScrollPreventionListener = null;
  }

  /**
   * Clean up all resources.
   */
  cleanup() {
    this.#cleanupFocusScrollPrevention();
    this.#previouslyFocusedElement = null;
  }
}
