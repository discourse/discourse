import { processBehavior } from "discourse/float-kit/lib/behavior-handler";
import { getFocusableElements } from "./focus-utils";

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
