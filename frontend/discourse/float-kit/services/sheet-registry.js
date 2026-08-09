import Service, { service } from "@ember/service";
import { getAllTabbableElements } from "discourse/float-kit/components/d-sheet/focus-utils";

const FIXED_ELEMENT_SELECTOR = '[data-d-sheet~="view"]';

export default class SheetRegistry extends Service {
  @service sheetLayerStore;

  scrollLockCount = 0;
  savedScrollPosition = [0, 0];
  scrollLockCleanup = null;
  scrollbarCompensation = null;
  isResizing = false;
  resizeTimeout = null;
  controllersWithScrollLock = new Set();
  #deactivatedViewState = new WeakMap();
  #scrollLockStyles = new Map();

  willDestroy() {
    super.willDestroy();

    this.sheetLayerStore.cleanupInert();
    if (this.scrollLockCount > 0 || this.scrollLockCleanup) {
      this.#disableScrollLock();
    }
    this.scrollLockCount = 0;
    this.controllersWithScrollLock.clear();
  }

  register(controller) {
    if (this.sheetLayerStore.hasSheet(controller)) {
      return;
    }

    this.sheetLayerStore.registerSheet(controller);

    this.updateScrollLock(controller, controller.inertOutside);

    if (controller.view) {
      this.#syncView(controller, controller.view);
    }

    this.sheetLayerStore.recalculateInertOutside();
  }

  unregister(controller) {
    if (!this.sheetLayerStore.hasSheet(controller)) {
      return;
    }

    this.#deactivateView(controller.view);
    controller.view?.removeAttribute("aria-modal");

    if (this.controllersWithScrollLock.has(controller.id)) {
      this.removeScrollLock();
      this.controllersWithScrollLock.delete(controller.id);
    }

    this.sheetLayerStore.unregisterSheet(controller.id);
    this.sheetLayerStore.recalculateInertOutside();
  }

  updateScrollLock(controller, shouldLock) {
    const hasLock = this.controllersWithScrollLock.has(controller.id);

    if (shouldLock && !hasLock) {
      this.applyScrollLock();
      this.controllersWithScrollLock.add(controller.id);
    } else if (!shouldLock && hasLock) {
      this.removeScrollLock();
      this.controllersWithScrollLock.delete(controller.id);
    }
  }

  updateInertOutside(controller, inertOutside) {
    if (!this.sheetLayerStore.hasSheet(controller)) {
      return;
    }

    const becameInert =
      Boolean(inertOutside) &&
      !this.controllersWithScrollLock.has(controller.id);
    this.updateScrollLock(controller, inertOutside);

    if (controller.view) {
      this.#syncView(controller, controller.view, inertOutside);
    }

    this.sheetLayerStore.recalculateInertOutside({
      recoverFocus: becameInert,
    });
  }

  viewRegistered(controller, view) {
    if (this.scrollLockCount > 0) {
      this.#applyScrollbarCompensation(view);
    }

    if (!this.sheetLayerStore.hasSheet(controller)) {
      view.removeAttribute("aria-modal");
      return;
    }

    this.#syncView(controller, view);
    this.sheetLayerStore.recalculateInertOutside();
  }

  findContainingSheet(element, excludedController) {
    return this.sheetLayerStore.findContainingSheet(
      element,
      excludedController
    );
  }

  applyScrollLock() {
    if (this.scrollLockCount === 0) {
      this.#enableScrollLock();
    }
    this.scrollLockCount++;
  }

  removeScrollLock() {
    if (this.scrollLockCount > 0) {
      this.scrollLockCount--;
      if (this.scrollLockCount === 0) {
        this.#disableScrollLock();
      }
    }
  }

  #enableScrollLock() {
    this.savedScrollPosition = [window.scrollX, window.scrollY];

    const xScrollbarThickness =
      window.innerWidth - document.documentElement.clientWidth;
    const yScrollbarThickness =
      window.innerHeight - document.documentElement.clientHeight;
    this.scrollbarCompensation = {
      x: `${xScrollbarThickness}px`,
      y: `${yScrollbarThickness}px`,
    };

    this.#setScrollLockStyle(document.body, "overflow", "hidden");
    document.querySelectorAll(FIXED_ELEMENT_SELECTOR).forEach((element) => {
      this.#applyScrollbarCompensation(element);
    });
    this.#setScrollLockStyle(
      document.body,
      "padding-right",
      this.scrollbarCompensation.x
    );
    this.#setScrollLockStyle(
      document.body,
      "padding-bottom",
      this.scrollbarCompensation.y
    );

    this.isResizing = false;
    this.resizeTimeout = null;

    const handleResize = () => {
      if (this.resizeTimeout !== null) {
        clearTimeout(this.resizeTimeout);
      }
      this.isResizing = true;
      this.resizeTimeout = setTimeout(() => {
        this.isResizing = false;
        this.resizeTimeout = null;
      }, 50);
    };

    const handleScroll = () => {
      if (!this.isResizing) {
        window.scrollTo(...this.savedScrollPosition);
      }
    };

    window.addEventListener("resize", handleResize);
    window.addEventListener("scroll", handleScroll, { passive: false });

    this.scrollLockCleanup = () => {
      window.removeEventListener("resize", handleResize);
      window.removeEventListener("scroll", handleScroll);
    };
  }

  #disableScrollLock() {
    this.#restoreScrollLockStyles();
    this.scrollbarCompensation = null;

    this.scrollLockCleanup?.();
    this.scrollLockCleanup = null;

    if (this.resizeTimeout !== null) {
      clearTimeout(this.resizeTimeout);
      this.resizeTimeout = null;
    }
    this.isResizing = false;
  }

  #syncView(controller, view, inertOutside = controller.inertOutside) {
    this.#restoreView(view);

    if (this.scrollLockCount > 0) {
      this.#applyScrollbarCompensation(view);
    }

    if (inertOutside) {
      view.setAttribute("aria-modal", "true");
    } else {
      view.removeAttribute("aria-modal");
    }
  }

  #deactivateView(view) {
    if (!view) {
      return;
    }

    let state = this.#deactivatedViewState.get(view);
    if (!state) {
      const tabIndexes = new Map();

      for (const element of getAllTabbableElements(view)) {
        tabIndexes.set(element, element.getAttribute("tabindex"));
        element.tabIndex = -1;
      }

      state = {
        ariaHidden: view.getAttribute("aria-hidden"),
        tabIndexes,
      };
      this.#deactivatedViewState.set(view, state);
    }

    view.setAttribute("aria-hidden", "true");
  }

  #restoreView(view) {
    const state = this.#deactivatedViewState.get(view);
    if (!state) {
      return;
    }

    if (view.getAttribute("aria-hidden") === "true") {
      if (state.ariaHidden === null) {
        view.removeAttribute("aria-hidden");
      } else {
        view.setAttribute("aria-hidden", state.ariaHidden);
      }
    }

    for (const [element, tabIndex] of state.tabIndexes) {
      if (element.getAttribute("tabindex") !== "-1") {
        continue;
      }

      if (tabIndex === null) {
        element.removeAttribute("tabindex");
      } else {
        element.setAttribute("tabindex", tabIndex);
      }
    }

    this.#deactivatedViewState.delete(view);
  }

  #applyScrollbarCompensation(element) {
    if (!this.scrollbarCompensation) {
      return;
    }

    this.#setScrollLockStyle(
      element,
      "--x-collapsed-scrollbar-thickness",
      this.scrollbarCompensation.x
    );
    this.#setScrollLockStyle(
      element,
      "--y-collapsed-scrollbar-thickness",
      this.scrollbarCompensation.y
    );
  }

  #setScrollLockStyle(element, property, value) {
    let elementStyles = this.#scrollLockStyles.get(element);
    if (!elementStyles) {
      elementStyles = new Map();
      this.#scrollLockStyles.set(element, elementStyles);
    }

    const currentValue = element.style.getPropertyValue(property);
    const currentPriority = element.style.getPropertyPriority(property);
    let state = elementStyles.get(property);

    if (
      !state ||
      currentValue !== state.ownedValue ||
      currentPriority !== state.ownedPriority
    ) {
      state = {
        originalPriority: currentPriority,
        originalValue: currentValue,
      };
      elementStyles.set(property, state);
    }

    element.style.setProperty(property, value);
    state.ownedPriority = element.style.getPropertyPriority(property);
    state.ownedValue = element.style.getPropertyValue(property);
  }

  #restoreScrollLockStyles() {
    for (const [element, elementStyles] of this.#scrollLockStyles) {
      for (const [property, state] of elementStyles) {
        if (
          element.style.getPropertyValue(property) !== state.ownedValue ||
          element.style.getPropertyPriority(property) !== state.ownedPriority
        ) {
          continue;
        }

        if (state.originalValue) {
          element.style.setProperty(
            property,
            state.originalValue,
            state.originalPriority
          );
        } else {
          element.style.removeProperty(property);
        }
      }
    }

    this.#scrollLockStyles.clear();
  }
}
