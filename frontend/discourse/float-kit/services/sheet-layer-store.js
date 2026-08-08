import { action } from "@ember/object";
import { cancel, run, schedule } from "@ember/runloop";
import Service from "@ember/service";
import setupFocusContainment from "discourse/float-kit/components/d-sheet/focus-containment";
import { processBehavior } from "discourse/float-kit/lib/behavior-handler";

const inertRefCounts = new WeakMap();

export default class SheetLayerStore extends Service {
  controllers = new Map();
  sheetOrder = [];
  rootsByComponentId = new Map();
  layerFocusState = new Map();
  inertElements = new Set();
  manualAutomaticLayerElements = new Set();
  detectedAutomaticLayerElements = new Set();
  mutationObserver = null;
  automaticLayerDetectionObserver = null;
  automaticLayerDetectionView = null;
  recalculateInertTimeout = null;
  focusContainmentCleanup = null;
  focusContainmentLastElement = null;
  clickOutsideCleanup = null;
  escapeKeyCleanup = null;
  pointerDownTarget = null;

  willDestroy() {
    super.willDestroy();
    cancel(this.recalculateInertTimeout);
    this.cleanupInert();
    this.#cleanupAutomaticLayerDetection();
    this.focusContainmentLastElement = null;
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

  hasSheet(controllerOrId) {
    const id =
      typeof controllerOrId === "string" ? controllerOrId : controllerOrId?.id;

    return id ? this.controllers.has(id) : false;
  }

  unregisterSheet(controllerOrId) {
    const id =
      typeof controllerOrId === "string" ? controllerOrId : controllerOrId?.id;

    if (!id) {
      return;
    }

    this.controllers.delete(id);
    this.sheetOrder = this.sheetOrder.filter((sheetId) => sheetId !== id);

    this.#syncGlobalListeners();
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

  @action
  registerAutomaticLayerElement(element) {
    if (element) {
      this.manualAutomaticLayerElements.add(element);
      this.recalculateInertOutside();
    }
  }

  @action
  unregisterAutomaticLayerElement(element) {
    if (element) {
      this.manualAutomaticLayerElements.delete(element);
      this.recalculateInertOutside();
    }
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
    this.#cleanupFocusContainment();

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
  }

  consumeClickOutside(event) {
    const target = event.target;
    const targetElement =
      target instanceof Element ? target : target?.parentElement;

    if (targetElement?.matches('[data-d-sheet~="pass-through"] *')) {
      this.pointerDownTarget = null;
      return;
    }

    if (!target || !target.isConnected) {
      this.pointerDownTarget = null;
      return;
    }

    if (target === document.body && this.pointerDownTarget !== document.body) {
      this.pointerDownTarget = null;
      return;
    }

    if (this.#targetIsInAutomaticLayer(target)) {
      this.pointerDownTarget = null;
      return;
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
  }

  setLayerFocusedLastBeforeShowing(sheetId, element) {
    if (!sheetId) {
      return;
    }

    const focusState = this.layerFocusState.get(sheetId) || {};
    focusState.elementFocusedLastBeforeShowing = element ?? null;
    this.layerFocusState.set(sheetId, focusState);
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
  }

  captureLayerFocusWasInsideOnClose(sheetId, viewElement) {
    if (!sheetId) {
      return;
    }

    const focusState = this.layerFocusState.get(sheetId) || {};
    const activeElement = document.activeElement;

    focusState.focusWasInsideOnClose =
      !!viewElement && !!activeElement && viewElement.contains(activeElement);

    this.layerFocusState.set(sheetId, focusState);
  }

  executeLayerDismissAutoFocus({ sheetId, viewElement, onDismissAutoFocus }) {
    if (!sheetId) {
      return;
    }

    const focusState = this.layerFocusState.get(sheetId) || {};
    const activeElement = document.activeElement;
    const focusWasInside =
      focusState.focusWasInsideOnClose ||
      (!!viewElement && !!activeElement && viewElement.contains(activeElement));

    focusState.focusWasInsideOnClose = false;
    this.layerFocusState.set(sheetId, focusState);

    if (!focusWasInside && document.contains(activeElement)) {
      focusState.elementFocusedLastBeforeShowing = null;
      this.layerFocusState.set(sheetId, focusState);
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
  }

  clearLayerFocusState(sheetId) {
    if (!sheetId) {
      return;
    }

    this.layerFocusState.delete(sheetId);
  }

  #processEscapeOnLayer({ sheetsInOrder, layerIndex, event }) {
    const sheet = sheetsInOrder[layerIndex];
    if (!sheet) {
      return;
    }

    if (!sheet.canAcceptDismissRequest) {
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
      sheet.requestDismiss();
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

    if (!sheet.canAcceptDismissRequest) {
      return;
    }

    const target = event.target;
    const content = sheet.content;
    const view = sheet.view;
    const rootElement = sheet.rootElement;

    if (rootElement?.contains(target) && !view?.contains(target)) {
      return;
    }

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
      sheet.requestDismiss();
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

    const hasInertOutside = sheetsInOrder.some((sheet) => sheet.inertOutside);

    if (!hasInertOutside || sheetsInOrder.length === 0) {
      this.#cleanupAutomaticLayerDetection();
      this.focusContainmentLastElement = null;
      return;
    }

    const focusContainmentRootElements = new Set();

    let automaticLayerDetectionView = null;

    for (let i = sheetsInOrder.length - 1; i >= 0; i--) {
      const sheet = sheetsInOrder[i];

      if (sheet.view) {
        focusContainmentRootElements.add(sheet.view);
      }

      if (sheet.inertOutside) {
        automaticLayerDetectionView = sheet.view;
        break;
      }
    }

    if (!automaticLayerDetectionView) {
      this.#cleanupAutomaticLayerDetection();
      this.focusContainmentLastElement = null;
      return;
    }

    this.#setupAutomaticLayerDetection(automaticLayerDetectionView);

    for (const element of this.#automaticLayerElements()) {
      if (element.isConnected) {
        focusContainmentRootElements.add(element);
      }
    }

    const guardElements = this.#setupFocusContainment(
      focusContainmentRootElements,
      automaticLayerDetectionView
    );

    this.#moveFocusIfNecessary(focusContainmentRootElements, sheetsInOrder);

    const inertRootElements = new Set([
      ...focusContainmentRootElements,
      ...guardElements,
    ]);
    document.querySelectorAll("[aria-live]").forEach((element) => {
      inertRootElements.add(element);
    });

    this.#applyInert(inertRootElements);
  }

  #setupFocusContainment(rootElements, viewElement) {
    const { cleanup, guardElements } = setupFocusContainment({
      rootElements: [...rootElements],
      viewElement,
      getElementFocusedLast: () => this.focusContainmentLastElement,
      setElementFocusedLast: (element) => {
        this.focusContainmentLastElement = element;
      },
    });

    this.focusContainmentCleanup = cleanup;
    return guardElements;
  }

  #cleanupFocusContainment() {
    this.focusContainmentCleanup?.();
    this.focusContainmentCleanup = null;
  }

  #targetIsInAutomaticLayer(target) {
    if (!(target instanceof Node)) {
      return false;
    }

    for (const element of this.#automaticLayerElements()) {
      if (element.isConnected && element.contains(target)) {
        return true;
      }
    }

    return false;
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

  #automaticLayerElements() {
    return new Set([
      ...this.manualAutomaticLayerElements,
      ...this.detectedAutomaticLayerElements,
    ]);
  }

  #setupAutomaticLayerDetection(viewElement) {
    if (!viewElement) {
      this.#cleanupAutomaticLayerDetection();
      return;
    }

    const viewChanged = this.automaticLayerDetectionView !== viewElement;
    if (viewChanged) {
      this.#cleanupAutomaticLayerDetection();
      this.automaticLayerDetectionView = viewElement;
    }

    this.#scanAutomaticLayerElements(viewElement);

    if (this.automaticLayerDetectionObserver) {
      return;
    }

    this.automaticLayerDetectionObserver = new MutationObserver(() => {
      if (this.#scanAutomaticLayerElements(viewElement)) {
        this.recalculateInertOutside();
      }
    });

    this.automaticLayerDetectionObserver.observe(document.documentElement, {
      childList: true,
    });
    this.automaticLayerDetectionObserver.observe(document.body, {
      childList: true,
    });
  }

  #cleanupAutomaticLayerDetection() {
    if (this.automaticLayerDetectionObserver) {
      this.automaticLayerDetectionObserver.disconnect();
      this.automaticLayerDetectionObserver = null;
    }

    this.automaticLayerDetectionView = null;
    this.detectedAutomaticLayerElements = new Set();
  }

  #scanAutomaticLayerElements(viewElement) {
    const detectedElements = new Set();
    const topLevelElement = this.#bodyChildForElement(viewElement);
    let candidate = topLevelElement
      ? topLevelElement.nextElementSibling
      : document.body.firstElementChild;

    while (candidate) {
      if (!this.#isIgnoredAutomaticLayerElement(candidate)) {
        detectedElements.add(candidate);
      }
      candidate = candidate.nextElementSibling;
    }

    const changed = !this.#setsAreEqual(
      detectedElements,
      this.detectedAutomaticLayerElements
    );

    this.detectedAutomaticLayerElements = detectedElements;
    return changed;
  }

  #bodyChildForElement(element) {
    for (let parent = element; parent; parent = parent.parentElement) {
      if (parent.parentElement === document.body) {
        return parent;
      }
    }

    return element.parentElement === document.body ? element : null;
  }

  #isIgnoredAutomaticLayerElement(element) {
    return (
      element.tagName === "SCRIPT" ||
      element.matches("[data-d-sheet], [data-d-sheet-clone]")
    );
  }

  #setsAreEqual(first, second) {
    if (first.size !== second.size) {
      return false;
    }

    for (const value of first) {
      if (!second.has(value)) {
        return false;
      }
    }

    return true;
  }

  #setupClickOutsideListener() {
    if (this.clickOutsideCleanup) {
      return;
    }

    const handlePointerDown = (event) => {
      run(() => {
        this.pointerDownTarget = event.target;
      });
    };

    const handleClick = (event) => {
      run(() => this.consumeClickOutside(event));
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
        run(() => this.consumeEscapeKey(event));
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

    this.#cleanupAutomaticLayerDetection();
    this.#cleanupClickOutsideListener();
    this.#cleanupEscapeKeyListener();
  }
}
