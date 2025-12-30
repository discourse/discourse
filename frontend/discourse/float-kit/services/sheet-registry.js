import { cancel, schedule } from "@ember/runloop";
import Service from "@ember/service";

const ariaHiddenRefCounts = new WeakMap();

/**
 * Service for managing sheet instances, click-outside handling,
 * scroll lock, and centralized inert management.
 */
export default class SheetRegistry extends Service {
  /** @type {Map<string, Object>} */
  sheets = new Map();

  /** @type {Object[]} */
  sheetsInOrder = [];
  /** @type {Function|null} */
  clickOutsideCleanup = null;
  /** @type {Function|null} */
  escapeKeyCleanup = null;
  /** @type {EventTarget|null} */
  pointerDownTarget = null;
  /** @type {number} */
  scrollLockCount = 0;
  /** @type {[number, number]} */
  savedScrollPosition = [0, 0];
  /** @type {Function|null} */
  scrollLockCleanup = null;
  /** @type {boolean} */
  isResizing = false;
  /** @type {number|null} */
  resizeTimeout = null;
  /** @type {Set<string>} */
  controllersWithScrollLock = new Set();
  /** @type {Map<string, Object>} Root components registered by componentId */
  #rootsByComponentId = new Map();

  /** @type {Function|null} */
  inertCleanup = null;

  /** @type {Set<Element>} */
  hiddenElements = new Set();

  /** @type {Set<Element>} */
  rootElements = new Set();

  /** @type {MutationObserver|null} */
  mutationObserver = null;

  /** @type {Object|null} */
  recalculateInertTimeout = null;

  /**
   * Cleans up all listeners and state when the service is destroyed.
   */
  willDestroy() {
    super.willDestroy();

    cancel(this.recalculateInertTimeout);
    this.cleanupClickOutsideListener();
    this.cleanupEscapeKeyListener();
    this.cleanupInert();
    if (this.scrollLockCleanup) {
      this.scrollLockCleanup();
      this.scrollLockCleanup = null;
    }
    this.scrollLockCount = 0;
  }

  /**
   * Registers a sheet controller with the registry.
   *
   * @param {Object} controller
   */
  register(controller) {
    this.sheets.set(controller.id, controller);
    this.sheetsInOrder.push(controller);

    if (this.sheetsInOrder.length === 1) {
      this.setupClickOutsideListener();
      this.setupEscapeKeyListener();
    }

    if (controller.inertOutside) {
      this.applyScrollLock();
      this.controllersWithScrollLock.add(controller.id);
    }

    this.recalculateInertOutside();
  }

  /**
   * Unregisters a sheet controller from the registry.
   *
   * @param {Object} controller
   */
  unregister(controller) {
    if (this.controllersWithScrollLock.has(controller.id)) {
      this.removeScrollLock();
      this.controllersWithScrollLock.delete(controller.id);
    }

    this.sheets.delete(controller.id);
    const index = this.sheetsInOrder.indexOf(controller);
    if (index !== -1) {
      this.sheetsInOrder.splice(index, 1);
    }

    if (this.sheetsInOrder.length === 0) {
      this.cleanupClickOutsideListener();
      this.cleanupEscapeKeyListener();
    }

    this.recalculateInertOutside();
  }

  /**
   * Updates scroll lock for a controller.
   *
   * @param {Object} controller
   * @param {boolean} shouldLock
   */
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

  /**
   * Notifies registry that a sheet's inertOutside state changed.
   *
   * @param {Object} controller
   * @param {boolean} inertOutside
   */
  updateInertOutside(controller, inertOutside) {
    this.updateScrollLock(controller, inertOutside);

    if (controller.view) {
      if (inertOutside) {
        controller.view.setAttribute("aria-modal", "true");
      } else {
        controller.view.removeAttribute("aria-modal");
      }
    }

    this.recalculateInertOutside();
  }

  /**
   * Recalculates which elements should have aria-hidden.
   * Collects all sheet views from topmost down to first inertOutside sheet.
   */
  recalculateInertOutside() {
    cancel(this.recalculateInertTimeout);

    this.recalculateInertTimeout = schedule("afterRender", () => {
      this.cleanupInert();

      const hasInertOutside = this.sheetsInOrder.some(
        (sheet) => sheet.inertOutside
      );

      if (!hasInertOutside || this.sheetsInOrder.length === 0) {
        return;
      }

      const rootElements = new Set();

      for (let i = this.sheetsInOrder.length - 1; i >= 0; i--) {
        const sheet = this.sheetsInOrder[i];

        if (sheet.view) {
          rootElements.add(sheet.view);
        }

        if (sheet.inertOutside) {
          break;
        }
      }

      document.querySelectorAll("[aria-live]").forEach((el) => {
        rootElements.add(el);
      });

      this.rootElements = rootElements;
      this.moveFocusIfNecessary(rootElements);
      this.applyAriaHidden(rootElements);
    });
  }

  /**
   * Moves focus to topmost sheet if currently outside protected elements.
   *
   * @param {Set<Element>} rootElements
   */
  moveFocusIfNecessary(rootElements) {
    const activeElement = document.activeElement;
    if (!activeElement || activeElement === document.body) {
      return;
    }

    const focusInRoot = [...rootElements].some((root) =>
      root.contains(activeElement)
    );

    if (!focusInRoot) {
      const topmostSheet = this.sheetsInOrder[this.sheetsInOrder.length - 1];
      if (topmostSheet?.view) {
        topmostSheet.view.focus({ preventScroll: true });
      }
    }
  }

  /**
   * Applies aria-hidden to elements outside the root elements.
   *
   * @param {Set<Element>} rootElements
   */
  applyAriaHidden(rootElements) {
    const hiddenElements = new Set();

    const treeWalker = document.createTreeWalker(
      document,
      NodeFilter.SHOW_ELEMENT,
      {
        acceptNode: (node) => {
          if (
            node instanceof HTMLElement &&
            node.dataset.liveAnnouncer === "true"
          ) {
            rootElements.add(node);
          }

          if (
            node.tagName === "HEAD" ||
            node.tagName === "SCRIPT" ||
            rootElements.has(node) ||
            (node.parentElement && hiddenElements.has(node.parentElement))
          ) {
            return NodeFilter.FILTER_REJECT;
          }

          if (
            (node instanceof HTMLElement &&
              node.getAttribute("role") === "row") ||
            [...rootElements].some((root) => node.contains(root))
          ) {
            return NodeFilter.FILTER_SKIP;
          }

          return NodeFilter.FILTER_ACCEPT;
        },
      }
    );

    let node = treeWalker.nextNode();
    while (node) {
      this.hideElement(node, hiddenElements);
      node = treeWalker.nextNode();
    }

    this.hiddenElements = hiddenElements;
    this.setupMutationObserver(rootElements);
  }

  /**
   * Hides an element with aria-hidden using reference counting.
   *
   * @param {Element} element
   * @param {Set<Element>} hiddenElements
   */
  hideElement(element, hiddenElements) {
    const count = ariaHiddenRefCounts.get(element) ?? 0;

    if (element.getAttribute("aria-hidden") !== "true" || count > 0) {
      if (count === 0) {
        element.setAttribute("aria-hidden", "true");
      }
      hiddenElements.add(element);
      ariaHiddenRefCounts.set(element, count + 1);
    }
  }

  /**
   * Sets up MutationObserver to apply aria-hidden to dynamically added content.
   *
   * @param {Set<Element>} rootElements
   */
  setupMutationObserver(rootElements) {
    this.mutationObserver = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type !== "childList" || mutation.addedNodes.length === 0) {
          continue;
        }

        const allProtected = [...rootElements, ...this.hiddenElements];
        if (allProtected.some((el) => el.contains(mutation.target))) {
          continue;
        }

        for (const addedNode of mutation.addedNodes) {
          if (!(addedNode instanceof HTMLElement)) {
            continue;
          }

          if (addedNode.dataset.liveAnnouncer === "true") {
            rootElements.add(addedNode);
          } else {
            this.hideElement(addedNode, this.hiddenElements);
          }
        }
      }
    });

    this.mutationObserver.observe(document, {
      childList: true,
      subtree: true,
    });
  }

  /**
   * Cleans up inert state - removes aria-hidden from hidden elements.
   */
  cleanupInert() {
    if (this.mutationObserver) {
      this.mutationObserver.disconnect();
      this.mutationObserver = null;
    }

    for (const element of this.hiddenElements) {
      const count = ariaHiddenRefCounts.get(element);
      if (count === 1) {
        element.removeAttribute("aria-hidden");
        ariaHiddenRefCounts.delete(element);
      } else if (count !== undefined) {
        ariaHiddenRefCounts.set(element, count - 1);
      }
    }

    this.hiddenElements = new Set();
    this.rootElements = new Set();
  }

  /**
   * @param {string} id
   * @returns {Object|undefined}
   */
  find(id) {
    return this.sheets.get(id);
  }

  /**
   * Registers a Root component by its componentId.
   *
   * @param {string} componentId
   * @param {Object} rootComponent
   */
  registerRoot(componentId, rootComponent) {
    this.#rootsByComponentId.set(componentId, rootComponent);
  }

  /**
   * Unregisters a Root component by its componentId.
   *
   * @param {string} componentId
   */
  unregisterRoot(componentId) {
    this.#rootsByComponentId.delete(componentId);
  }

  /**
   * Gets a Root component by its componentId.
   *
   * @param {string} componentId
   * @returns {Object|undefined}
   */
  getRootByComponentId(componentId) {
    return this.#rootsByComponentId.get(componentId);
  }

  /**
   * Gets the topmost sheet (last in order).
   *
   * @returns {Object|null}
   */
  getTopmostSheet() {
    if (this.sheetsInOrder.length === 0) {
      return null;
    }
    return this.sheetsInOrder[this.sheetsInOrder.length - 1];
  }

  /**
   * Applies scroll lock with reference counting.
   */
  applyScrollLock() {
    if (this.scrollLockCount === 0) {
      this.savedScrollPosition = [window.scrollX, window.scrollY];
      document.documentElement.style.setProperty("overflow", "hidden");

      const handleResize = () => {
        clearTimeout(this.resizeTimeout);
        this.isResizing = true;
        this.resizeTimeout = setTimeout(() => {
          this.isResizing = false;
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
        if (this.resizeTimeout) {
          clearTimeout(this.resizeTimeout);
          this.resizeTimeout = null;
        }
      };
    }
    this.scrollLockCount++;
  }

  /**
   * Removes scroll lock with reference counting.
   */
  removeScrollLock() {
    if (this.scrollLockCount > 0) {
      this.scrollLockCount--;
      if (this.scrollLockCount === 0) {
        document.documentElement.style.removeProperty("overflow");
        if (this.scrollLockCleanup) {
          this.scrollLockCleanup();
          this.scrollLockCleanup = null;
        }
      }
    }
  }

  /**
   * Sets up global click listener for click-outside handling.
   */
  setupClickOutsideListener() {
    const handlePointerDown = (event) => {
      this.pointerDownTarget = event.target;
    };

    const handleClick = (event) => {
      this.handleClickOutside(event);
    };

    document.addEventListener("pointerdown", handlePointerDown, {
      capture: true,
    });
    document.addEventListener("click", handleClick, {
      capture: true,
    });

    this.clickOutsideCleanup = () => {
      document.removeEventListener("pointerdown", handlePointerDown, {
        capture: true,
      });
      document.removeEventListener("click", handleClick, {
        capture: true,
      });
    };
  }

  /**
   * Cleans up global click listener.
   */
  cleanupClickOutsideListener() {
    if (this.clickOutsideCleanup) {
      this.clickOutsideCleanup();
      this.clickOutsideCleanup = null;
    }
    this.pointerDownTarget = null;
  }

  /**
   * Sets up a single global keydown listener for Escape key handling.
   * Only the topmost sheet handles Escape.
   */
  setupEscapeKeyListener() {
    const handleKeyDown = (event) => {
      if (event.key === "Escape") {
        this.handleEscapeKey(event);
      }
    };

    document.addEventListener("keydown", handleKeyDown);

    this.escapeKeyCleanup = () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }

  /**
   * Cleans up global escape key listener.
   */
  cleanupEscapeKeyListener() {
    if (this.escapeKeyCleanup) {
      this.escapeKeyCleanup();
      this.escapeKeyCleanup = null;
    }
  }

  /**
   * Processes a behavior handler that can be either an object or a function.
   *
   * @param {Object|Function} handler - The handler (object or function with changeDefault)
   * @param {Object} defaultBehavior - The default behavior object
   * @param {Event} nativeEvent - The native DOM event
   * @returns {Object} The resolved behavior object
   */
  processBehaviorHandler(handler, defaultBehavior, nativeEvent) {
    let result = { ...defaultBehavior };
    if (handler) {
      if (typeof handler === "function") {
        const customEvent = {
          ...defaultBehavior,
          nativeEvent,
          changeDefault(changedBehavior) {
            result = { ...defaultBehavior, ...changedBehavior };
            Object.assign(this, changedBehavior);
          },
        };
        customEvent.changeDefault = customEvent.changeDefault.bind(customEvent);
        handler(customEvent);
      } else {
        result = { ...defaultBehavior, ...handler };
      }
    }
    return result;
  }

  /**
   * Handles Escape key for stacked sheets.
   * Processes from topmost sheet down, respecting stopOverlayPropagation.
   *
   * @param {KeyboardEvent} event
   */
  handleEscapeKey(event) {
    const layerCount = this.sheetsInOrder.length;
    if (layerCount > 0) {
      this.processEscapeOnLayer(layerCount - 1, event);
    }
  }

  /**
   * Processes Escape key on a specific layer.
   * Recursively processes lower layers if stopOverlayPropagation is false.
   *
   * @param {number} layerIndex - Index of the layer to process
   * @param {KeyboardEvent} event - The keyboard event
   */
  processEscapeOnLayer(layerIndex, event) {
    const sheet = this.sheetsInOrder[layerIndex];
    if (!sheet) {
      return;
    }

    if (sheet.currentState !== "open") {
      return;
    }

    const behavior = this.processBehaviorHandler(
      sheet.onEscapeKeyDown,
      {
        nativePreventDefault: true,
        dismiss: true,
        stopOverlayPropagation: true,
      },
      event
    );

    if (behavior.nativePreventDefault !== false) {
      event.preventDefault();
    }

    if (behavior.dismiss !== false && sheet.role !== "alertdialog") {
      sheet.close();
    }

    if (behavior.stopOverlayPropagation === false && layerIndex > 0) {
      this.processEscapeOnLayer(layerIndex - 1, event);
    }
  }

  /**
   * Handles click-outside events.
   *
   * @param {Event} event
   */
  handleClickOutside(event) {
    const target = event.target;

    if (!target || !target.isConnected) {
      this.pointerDownTarget = null;
      return;
    }

    if (target === document.body && this.pointerDownTarget !== document.body) {
      this.pointerDownTarget = null;
      return;
    }

    const layerCount = this.sheetsInOrder.length;
    if (layerCount > 0) {
      this.processClickOnLayer(layerCount - 1, event);
    }

    this.pointerDownTarget = null;
  }

  /**
   * Processes click on a specific layer.
   *
   * @param {number} layerIndex
   * @param {Event} event
   */
  processClickOnLayer(layerIndex, event) {
    const sheet = this.sheetsInOrder[layerIndex];
    if (!sheet) {
      return;
    }

    if (sheet.currentState !== "open") {
      return;
    }

    const target = event.target;
    const scrollContainer = sheet.scrollContainer;
    const backdrop = sheet.backdrop;
    const view = sheet.view;
    const content = sheet.content;

    const isOnScrollContainer = scrollContainer === target;
    const isOnBackdrop = backdrop === target;
    const isOutsideView = view && !view.contains(target);
    const isInsideContent = content?.contains(target);

    const isClickOutside =
      isOnScrollContainer ||
      isOnBackdrop ||
      (isOutsideView && !isInsideContent);

    if (isClickOutside) {
      const behavior = this.processBehaviorHandler(
        sheet.onClickOutside,
        { dismiss: true, stopOverlayPropagation: true },
        event
      );

      if (behavior.dismiss && sheet.role !== "alertdialog") {
        sheet.close();
      }

      if (!behavior.stopOverlayPropagation && layerIndex > 0) {
        this.processClickOnLayer(layerIndex - 1, event);
      }
    }
  }
}
