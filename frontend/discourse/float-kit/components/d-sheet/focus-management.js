/**
 * Focus management module for d-sheet components.
 *
 * Handles automatic focus control when sheets are presented and dismissed, including:
 * - Capturing and restoring previously focused elements
 * - Finding appropriate auto-focus targets within sheet content
 * - Preventing unwanted scroll during focus changes
 * - Respecting aria-hidden, inert, and other accessibility constraints
 */
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
 * Data attribute for elements to skip during auto-focus (scroll-container).
 *
 * @type {string}
 */
const AUTOFOCUS_SKIP_SELECTOR = "[data-d-sheet~='scroll-container']";

/**
 * Data attribute for Scroll.View elements (used to skip when finding first focusable).
 *
 * @type {string}
 */
const SCROLL_VIEW_SELECTOR = "[data-d-scroll~='view']";

/**
 * Get the first element from an array that doesn't match the Scroll.View selector.
 * This skips Scroll.View containers when finding the first focusable child.
 *
 * @param {HTMLElement[]} elements - Array of elements to search
 * @returns {HTMLElement|undefined} First safe element or first element if none match
 */
function getFirstSafeElement(elements) {
  for (let i = 0; i < elements.length; ++i) {
    if (!elements[i].matches(SCROLL_VIEW_SELECTOR)) {
      return elements[i];
    }
  }
  return elements[0];
}

/**
 * Get focusable and tabbable elements within a container.
 *
 * @param {HTMLElement} container - The container element to search within
 * @param {string[]} [additionalSkipSelectors] - Additional selectors for elements to skip
 * @returns {{ safelyFocusableElements: HTMLElement[], safelyTabbableElements: HTMLElement[] }} Object containing arrays of focusable and tabbable elements
 */
function getFocusableElements(container, additionalSkipSelectors = []) {
  if (!container) {
    return { safelyFocusableElements: [], safelyTabbableElements: [] };
  }

  const skipSelector = [
    ...additionalSkipSelectors,
    ...SKIPPABLE_SELECTORS,
  ].join(",");

  const elements = [
    ...(container.matches(FOCUSABLE_SELECTOR) ? [container] : []),
    ...container.querySelectorAll(FOCUSABLE_SELECTOR),
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
 */
export default class FocusManagement {
  /**
   * The sheet controller instance.
   *
   * @type {Object}
   */
  controller;

  /**
   * Creates a new FocusManagement instance.
   *
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.controller = controller;
  }

  /**
   * Get the view element from controller.
   *
   * @returns {HTMLElement|null} The view element or null if not available
   */
  get #view() {
    return this.controller.view;
  }

  get #layerStore() {
    return this.controller.sheetRegistry?.sheetLayerStore;
  }

  setPreviouslyFocusedElement(element) {
    this.#layerStore?.setLayerFocusedLastBeforeShowing(
      this.controller.id,
      element
    );
  }

  captureFocusWasInsideOnClose() {
    this.#layerStore?.captureLayerFocusWasInsideOnClose(
      this.controller.id,
      this.#view
    );
  }

  /**
   * Capture the currently focused element before the sheet opens.
   */
  capturePreviouslyFocusedElement() {
    this.#layerStore?.captureLayerFocusedLastBeforeShowingFromActive(
      this.controller.id
    );
  }

  /**
   * Find the appropriate element to auto-focus when the sheet is presented.
   *
   * @returns {HTMLElement|null} The element to focus, or null if no suitable target found
   */
  findAutoFocusTarget() {
    if (!this.#view) {
      return null;
    }

    const { safelyTabbableElements } = getFocusableElements(this.#view, [
      AUTOFOCUS_SKIP_SELECTOR,
    ]);

    const firstTabbable = getFirstSafeElement(safelyTabbableElements);

    return firstTabbable ?? this.#view;
  }

  /**
   * Execute auto-focus when the sheet is presented.
   * Respects the onPresentAutoFocus behavior handler.
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
   * Respects the onDismissAutoFocus behavior handler.
   */
  executeAutoFocusOnDismiss() {
    this.#layerStore?.executeLayerDismissAutoFocus({
      sheetId: this.controller.id,
      viewElement: this.#view,
      onDismissAutoFocus: this.controller.onDismissAutoFocus,
    });
  }

  /**
   * Clean up all resources and reset state.
   */
  cleanup() {
    this.#layerStore?.clearLayerFocusState(this.controller.id);
  }
}
