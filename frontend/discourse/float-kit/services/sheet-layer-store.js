import { cancel, schedule } from "@ember/runloop";
import Service from "@ember/service";
import { processBehavior } from "discourse/float-kit/lib/behavior-handler";

const inertRefCounts = new WeakMap();

export default class SheetLayerStore extends Service {
  controllers = new Map();
  sheetOrder = [];
  rootsByComponentId = new Map();
  layers = new Map();
  layerFocusState = new Map();
  inertElements = new Set();
  rootElements = new Set();
  mutationObserver = null;
  recalculateInertTimeout = null;
  clickOutsideCleanup = null;
  escapeKeyCleanup = null;
  pointerDownTarget = null;

  willDestroy() {
    super.willDestroy();
    cancel(this.recalculateInertTimeout);
    this.cleanupInert();
    this.#cleanupClickOutsideListener();
    this.#cleanupEscapeKeyListener();
  }

  registerSheet(controller) {
    if (!controller?.id) {
      return;
    }

    this.controllers.set(controller.id, controller);

    if (!this.sheetOrder.includes(controller.id)) {
      this.sheetOrder.push(controller.id);
    }

    this.#syncGlobalListeners();
  }

  unregisterSheet(controllerOrId) {
    const id =
      typeof controllerOrId === "string" ? controllerOrId : controllerOrId?.id;

    if (!id) {
      return;
    }

    this.controllers.delete(id);
    this.removeLayer(id);
    this.sheetOrder = this.sheetOrder.filter((sheetId) => sheetId !== id);

    this.#syncGlobalListeners();
  }

  updateSheet(controller) {
    if (!controller?.id) {
      return;
    }

    this.controllers.set(controller.id, controller);
  }

  registerRoot(componentId, rootComponent) {
    if (!componentId) {
      return;
    }

    this.rootsByComponentId.set(componentId, rootComponent);
  }

  unregisterRoot(componentId) {
    if (!componentId) {
      return;
    }

    this.rootsByComponentId.delete(componentId);
  }

  getRootByComponentId(componentId) {
    return this.rootsByComponentId.get(componentId);
  }

  syncLayerFromSheet(controller) {
    if (!controller?.id) {
      return;
    }

    const focusState = this.layerFocusState.get(controller.id);

    this.layers.set(controller.id, {
      sheetId: controller.id,
      inertOutside: controller.inertOutside ?? true,
      viewElement: controller.view ?? null,
      backdropElement: controller.backdrop ?? null,
      scrollContainerElement: controller.scrollContainer ?? null,
      contentElement: controller.content ?? null,
      elementFocusedLastBeforeShowing:
        focusState?.elementFocusedLastBeforeShowing ?? null,
      focusWasInsideOnClose: focusState?.focusWasInsideOnClose ?? false,
    });
  }

  removeLayer(sheetId) {
    if (!sheetId) {
      return;
    }

    this.layers.delete(sheetId);
  }

  recalculateInertOutside() {
    cancel(this.recalculateInertTimeout);

    this.recalculateInertTimeout = schedule("afterRender", () => {
      this.#runInertOutsideRecalculation();
    });
  }

  flushInertOutside() {
    cancel(this.recalculateInertTimeout);
    this.#runInertOutsideRecalculation();
  }

  cleanupInert() {
    if (this.mutationObserver) {
      this.mutationObserver.disconnect();
      this.mutationObserver = null;
    }

    for (const element of this.inertElements) {
      const count = inertRefCounts.get(element);
      if (count === 1) {
        element.inert = false;
        inertRefCounts.delete(element);
      } else if (count !== undefined) {
        inertRefCounts.set(element, count - 1);
      }
    }

    this.inertElements = new Set();
    this.rootElements = new Set();
  }

  consumeEscapeKey(event) {
    const sheetsInOrder = this.#orderedControllers();
    const layerCount = sheetsInOrder.length;

    if (layerCount > 0) {
      this.#processEscapeOnLayer({
        sheetsInOrder,
        layerIndex: layerCount - 1,
        event,
      });
    }

    return true;
  }

  consumeClickOutside(event) {
    const target = event.target;
    const targetElement =
      target instanceof Element ? target : target?.parentElement;

    if (targetElement?.matches('[data-d-sheet~="pass-through"] *')) {
      this.pointerDownTarget = null;
      return true;
    }

    if (!target || !target.isConnected) {
      this.pointerDownTarget = null;
      return true;
    }

    if (target === document.body && this.pointerDownTarget !== document.body) {
      this.pointerDownTarget = null;
      return true;
    }

    const sheetsInOrder = this.#orderedControllers();
    const layerCount = sheetsInOrder.length;
    if (layerCount > 0) {
      this.#processClickOnLayer({
        sheetsInOrder,
        layerIndex: layerCount - 1,
        event,
      });
    }

    this.pointerDownTarget = null;
    return true;
  }

  setLayerFocusedLastBeforeShowing(sheetId, element) {
    if (!sheetId) {
      return;
    }

    const focusState = this.layerFocusState.get(sheetId) || {};
    focusState.elementFocusedLastBeforeShowing = element ?? null;
    this.layerFocusState.set(sheetId, focusState);
    this.#syncLayerFocusStateToLayer(sheetId);
  }

  captureLayerFocusedLastBeforeShowingFromActive(sheetId) {
    if (!sheetId) {
      return;
    }

    const focusState = this.layerFocusState.get(sheetId) || {};
    if (focusState.elementFocusedLastBeforeShowing) {
      return;
    }

    focusState.elementFocusedLastBeforeShowing = document.activeElement;
    this.layerFocusState.set(sheetId, focusState);
    this.#syncLayerFocusStateToLayer(sheetId);
  }

  captureLayerFocusWasInsideOnClose(sheetId, viewElement) {
    if (!sheetId) {
      return;
    }

    const focusState = this.layerFocusState.get(sheetId) || {};
    const activeElement = document.activeElement;

    focusState.focusWasInsideOnClose =
      !!viewElement &&
      !!activeElement &&
      viewElement.contains(activeElement);

    this.layerFocusState.set(sheetId, focusState);
    this.#syncLayerFocusStateToLayer(sheetId);
  }

  executeLayerDismissAutoFocus({ sheetId, viewElement, onDismissAutoFocus }) {
    if (!sheetId) {
      return;
    }

    const focusState = this.layerFocusState.get(sheetId) || {};
    const activeElement = document.activeElement;
    const focusWasInside =
      focusState.focusWasInsideOnClose ||
      (!!viewElement &&
        !!activeElement &&
        viewElement.contains(activeElement));

    focusState.focusWasInsideOnClose = false;
    this.layerFocusState.set(sheetId, focusState);
    this.#syncLayerFocusStateToLayer(sheetId);

    if (!focusWasInside && document.contains(activeElement)) {
      focusState.elementFocusedLastBeforeShowing = null;
      this.layerFocusState.set(sheetId, focusState);
      this.#syncLayerFocusStateToLayer(sheetId);
      return;
    }

    const behavior = processBehavior({
      nativeEvent: null,
      defaultBehavior: { focus: true },
      handler: onDismissAutoFocus,
    });

    if (behavior.focus === false) {
      focusState.elementFocusedLastBeforeShowing = null;
      this.layerFocusState.set(sheetId, focusState);
      this.#syncLayerFocusStateToLayer(sheetId);
      return;
    }

    const target =
      focusState.elementFocusedLastBeforeShowing &&
      document.contains(focusState.elementFocusedLastBeforeShowing)
        ? focusState.elementFocusedLastBeforeShowing
        : document.body;

    target.focus({ preventScroll: true });
    focusState.elementFocusedLastBeforeShowing = null;
    this.layerFocusState.set(sheetId, focusState);
    this.#syncLayerFocusStateToLayer(sheetId);
  }

  clearLayerFocusState(sheetId) {
    if (!sheetId) {
      return;
    }

    this.layerFocusState.delete(sheetId);
    this.#syncLayerFocusStateToLayer(sheetId);
  }

  #processEscapeOnLayer({ sheetsInOrder, layerIndex, event }) {
    const sheet = sheetsInOrder[layerIndex];
    if (!sheet) {
      return;
    }

    if (!sheet.state.openness.isOpen) {
      return;
    }

    const behavior = processBehavior({
      handler: sheet.onEscapeKeyDown,
      defaultBehavior: {
        nativePreventDefault: true,
        dismiss: true,
        stopOverlayPropagation: true,
      },
      nativeEvent: event,
    });

    if (behavior.nativePreventDefault !== false) {
      event.preventDefault();
    }

    if (behavior.dismiss !== false && sheet.role !== "alertdialog") {
      sheet.close();
    }

    if (behavior.stopOverlayPropagation === false && layerIndex > 0) {
      this.#processEscapeOnLayer({
        sheetsInOrder,
        layerIndex: layerIndex - 1,
        event,
      });
    }
  }

  #processClickOnLayer({ sheetsInOrder, layerIndex, event }) {
    const sheet = sheetsInOrder[layerIndex];
    if (!sheet) {
      return;
    }

    if (!sheet.state.openness.isOpen) {
      return;
    }

    const target = event.target;
    const content = sheet.content;
    const view = sheet.view;
    const isClickOutside =
      (view && !view.contains(target)) ||
      (view && content && !content.contains(target));

    if (!isClickOutside) {
      return;
    }

    const behavior = processBehavior({
      handler: sheet.onClickOutside,
      defaultBehavior: { dismiss: true, stopOverlayPropagation: true },
      nativeEvent: event,
    });

    if (behavior.dismiss && sheet.role !== "alertdialog") {
      sheet.close();
    }

    if (!behavior.stopOverlayPropagation && layerIndex > 0) {
      this.#processClickOnLayer({
        sheetsInOrder,
        layerIndex: layerIndex - 1,
        event,
      });
    }
  }

  #orderedControllers() {
    const orderedControllers = [];

    for (const sheetId of this.sheetOrder) {
      const controller = this.controllers.get(sheetId);
      if (controller) {
        orderedControllers.push(controller);
      }
    }

    return orderedControllers;
  }

  #runInertOutsideRecalculation() {
    this.cleanupInert();

    const sheetsInOrder = this.#orderedControllers();
    for (const sheet of sheetsInOrder) {
      this.syncLayerFromSheet(sheet);
    }

    const hasInertOutside = sheetsInOrder.some((sheet) => sheet.inertOutside);

    if (!hasInertOutside || sheetsInOrder.length === 0) {
      return;
    }

    const rootElements = new Set();

    for (let i = sheetsInOrder.length - 1; i >= 0; i--) {
      const sheet = sheetsInOrder[i];

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
    this.#moveFocusIfNecessary(rootElements, sheetsInOrder);
    this.#applyInert(rootElements);
  }

  #moveFocusIfNecessary(rootElements, sheetsInOrder) {
    const activeElement = document.activeElement;
    if (!activeElement || activeElement === document.body) {
      return;
    }

    const focusInRoot = [...rootElements].some((root) =>
      root.contains(activeElement)
    );

    if (focusInRoot) {
      return;
    }

    const topmostSheet = sheetsInOrder[sheetsInOrder.length - 1];
    if (topmostSheet?.view) {
      topmostSheet.view.focus({ preventScroll: true });
    }
  }

  #applyInert(rootElements) {
    const inertElements = new Set();

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
            (node.parentElement && inertElements.has(node.parentElement))
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
      this.#makeElementInert(node, inertElements);
      node = treeWalker.nextNode();
    }

    this.inertElements = inertElements;
    this.#setupMutationObserver(rootElements);
  }

  #makeElementInert(element, inertElements) {
    const count = inertRefCounts.get(element) ?? 0;

    if (!element.hasAttribute("inert") || count > 0) {
      if (count === 0) {
        element.inert = true;
      }
      inertElements.add(element);
      inertRefCounts.set(element, count + 1);
    }
  }

  #setupMutationObserver(rootElements) {
    this.mutationObserver = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type !== "childList" || mutation.addedNodes.length === 0) {
          continue;
        }

        const allProtected = [...rootElements, ...this.inertElements];
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
            this.#makeElementInert(addedNode, this.inertElements);
          }
        }
      }
    });

    this.mutationObserver.observe(document, {
      childList: true,
      subtree: true,
    });
  }

  #setupClickOutsideListener() {
    if (this.clickOutsideCleanup) {
      return;
    }

    const handlePointerDown = (event) => {
      this.pointerDownTarget = event.target;
    };

    const handleClick = (event) => {
      this.consumeClickOutside(event);
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
      this.clickOutsideCleanup = null;
    };
  }

  #cleanupClickOutsideListener() {
    if (this.clickOutsideCleanup) {
      this.clickOutsideCleanup();
    }
    this.pointerDownTarget = null;
  }

  #setupEscapeKeyListener() {
    if (this.escapeKeyCleanup) {
      return;
    }

    const handleKeyDown = (event) => {
      if (event.key === "Escape") {
        this.consumeEscapeKey(event);
      }
    };

    document.addEventListener("keydown", handleKeyDown);

    this.escapeKeyCleanup = () => {
      document.removeEventListener("keydown", handleKeyDown);
      this.escapeKeyCleanup = null;
    };
  }

  #cleanupEscapeKeyListener() {
    if (this.escapeKeyCleanup) {
      this.escapeKeyCleanup();
    }
  }

  #syncGlobalListeners() {
    if (this.sheetOrder.length > 0) {
      this.#setupClickOutsideListener();
      this.#setupEscapeKeyListener();
      return;
    }

    this.#cleanupClickOutsideListener();
    this.#cleanupEscapeKeyListener();
  }

  #syncLayerFocusStateToLayer(sheetId) {
    const layer = this.layers.get(sheetId);
    if (!layer) {
      return;
    }

    const focusState = this.layerFocusState.get(sheetId) || {};
    this.layers.set(sheetId, {
      ...layer,
      elementFocusedLastBeforeShowing:
        focusState.elementFocusedLastBeforeShowing ?? null,
      focusWasInsideOnClose: focusState.focusWasInsideOnClose ?? false,
    });
  }

}
