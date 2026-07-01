import { processBehavior } from "discourse/float-kit/lib/behavior-handler";

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
const SKIPPABLE_SELECTORS = [
  "[aria-hidden='true']",
  "[aria-hidden='true'] *",
  "[inert]",
  "[inert] *",
];
const AUTOFOCUS_SKIP_SELECTOR = "[data-d-sheet~='scroll-container']";
const SCROLL_VIEW_SELECTOR = "[data-d-scroll~='view']";
function getFirstSafeElement(elements) {
  for (let i = 0; i < elements.length; ++i) {
    if (!elements[i].matches(SCROLL_VIEW_SELECTOR)) {
      return elements[i];
    }
  }
  return elements[0];
}
function getFocusableElements(container, additionalSkipSelectors = []) {
  if (!container) {
    return { safelyTabbableElements: [] };
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

  const safelyTabbableElements = elementsWithData
    .filter((data) => data.tabbable && !data.skippable)
    .map((data) => data.element);

  return { safelyTabbableElements };
}

export default class FocusManagement {
  controller;

  constructor(controller) {
    this.controller = controller;
  }

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

  capturePreviouslyFocusedElement() {
    this.#layerStore?.captureLayerFocusedLastBeforeShowingFromActive(
      this.controller.id
    );
  }

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

  executeAutoFocusOnDismiss() {
    this.#layerStore?.executeLayerDismissAutoFocus({
      sheetId: this.controller.id,
      viewElement: this.#view,
      onDismissAutoFocus: this.controller.onDismissAutoFocus,
    });
  }

  cleanup() {
    this.#layerStore?.clearLayerFocusState(this.controller.id);
  }
}
