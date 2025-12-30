import { modifier } from "ember-modifier";
import { isCloneElement } from "discourse/float-kit/lib/utils";
import { isKeyboardVisible } from "discourse/lib/utilities";
import { capabilities } from "discourse/services/capabilities";
import {
  findClosestScrollContainer,
  isColorOrSelect,
  isInsidePreventionContainer,
  isNearViewportBottom,
  isPasswordRelatedInput,
} from "./focus-scroll-utils";
import isTextInput from "./is-text-input";

/**
 * Previous blur target - tracks the element that lost focus during clone technique.
 *
 * @type {Element|null}
 */
let previousBlurTarget = null;

/**
 * Previous focus target - tracks the element receiving focus during clone technique.
 *
 * @type {Element|null}
 */
let previousFocusTarget = null;

/**
 * Get the tracked blur/focus targets and reset them.
 *
 * @param {FocusEvent} event - The blur event
 * @returns {{ fromElement: Element|null, toElement: Element|null }}
 */
export function consumeFocusTrackingState(event) {
  const fromElement = previousBlurTarget ?? event.target;
  const toElement = previousFocusTarget ?? event.relatedTarget;

  previousBlurTarget = null;
  previousFocusTarget = null;

  return { fromElement, toElement };
}

/**
 * Global state for native focus scroll prevention.
 */
const globalState = {
  /** @type {Set<string>} - IDs of registered preventers */
  preventers: new Set(),
  /** @type {Function|null} - Cleanup function for global listeners */
  cleanup: null,
  /** @type {number} - Counter for generating unique IDs */
  idCounter: 0,
};

/**
 * Generate a unique ID for a preventer instance.
 *
 * @returns {string}
 */
function generatePreventerId() {
  return `d-scroll-focus-prevention-${++globalState.idCounter}`;
}

/**
 * Set up global document listeners for focus scroll prevention.
 *
 * @returns {Function} Cleanup function
 */
function setupGlobalListeners() {
  const handleTouchStart = (event) => {
    const target = event.target;
    if (isInsidePreventionContainer(target)) {
      const scrollContainer = findClosestScrollContainer(target);
      scrollContainer?.focus({ preventScroll: true });
      document.removeEventListener("touchstart", handleTouchStart, {
        capture: true,
      });
    }
  };

  const handleBlur = (event) => {
    const target = event.target;
    const relatedTarget = event.relatedTarget;

    if (!relatedTarget) {
      document.addEventListener("touchstart", handleTouchStart, {
        capture: true,
        passive: false,
      });
      return;
    }

    if (!isInsidePreventionContainer(relatedTarget)) {
      return;
    }

    if (isColorOrSelect(relatedTarget)) {
      document.addEventListener("touchstart", handleTouchStart, {
        capture: true,
        passive: false,
      });
    }

    if (
      (!isTextInput(relatedTarget) && !isColorOrSelect(relatedTarget)) ||
      isCloneElement(target)
    ) {
      return;
    }

    if (
      !isPasswordRelatedInput(relatedTarget) &&
      isTextInput(target) &&
      isNearViewportBottom(target)
    ) {
      const clone = target.cloneNode(false);
      clone.removeAttribute("id");
      clone.setAttribute("data-d-scroll-clone", "true");
      clone.style.setProperty("position", "fixed");
      clone.style.setProperty("left", "0");
      clone.style.setProperty("top", "0");
      clone.style.setProperty("transform", "translateY(-3000px) scale(0)");
      document.documentElement.appendChild(clone);

      previousFocusTarget = relatedTarget;
      clone.focus({ preventScroll: true });

      setTimeout(() => {
        previousBlurTarget = target;
        previousFocusTarget = relatedTarget;
        relatedTarget.focus({ preventScroll: true });
        clone.remove();
      }, 32);
    } else {
      previousFocusTarget = relatedTarget;
      relatedTarget.focus({ preventScroll: true });
    }
  };

  const handleTouchEnd = (event) => {
    const target = event.target;
    const isActive = target === document.activeElement;
    const isText = isTextInput(target);
    const keyboardVisible = isKeyboardVisible();
    const insideContainer = isInsidePreventionContainer(target);

    if (isActive && isText && !keyboardVisible && insideContainer) {
      const scrollContainer = findClosestScrollContainer(target);
      scrollContainer?.focus({ preventScroll: true });
    }
  };

  const handleFocusIn = (event) => {
    const target = event.target;
    if (
      target &&
      "setSelectionRange" in target &&
      (["password", "search", "tel", "text", "url"].includes(target.type) ||
        target instanceof HTMLTextAreaElement) &&
      target.dScrollFocusedBefore !== true
    ) {
      const length = target.value?.length ?? 0;
      target.setSelectionRange?.(length, length);
      target.dScrollFocusedBefore = true;
    }
  };

  document.addEventListener("blur", handleBlur, {
    capture: true,
    passive: false,
  });
  document.addEventListener("touchstart", handleTouchStart, {
    capture: true,
    passive: true,
  });
  document.addEventListener("touchend", handleTouchEnd, {
    capture: true,
    passive: true,
  });
  document.addEventListener("focusin", handleFocusIn);

  return () => {
    document.removeEventListener("blur", handleBlur, { capture: true });
    document.removeEventListener("touchstart", handleTouchStart, {
      capture: true,
    });
    document.removeEventListener("touchend", handleTouchEnd, { capture: true });
    document.removeEventListener("focusin", handleFocusIn);
  };
}

/**
 * Register a scroll container for focus scroll prevention.
 *
 * @returns {string} The preventer ID for unregistering
 */
function registerPreventer() {
  const id = generatePreventerId();
  globalState.preventers.add(id);
  processPreventersChanges();
  return id;
}

/**
 * Unregister a scroll container from focus scroll prevention.
 *
 * @param {string} id - The preventer ID to remove
 */
function unregisterPreventer(id) {
  globalState.preventers.delete(id);
  processPreventersChanges();
}

/**
 * Process changes to the preventers list.
 * Sets up or tears down global listeners based on whether any preventers are registered.
 */
function processPreventersChanges() {
  if (!capabilities.isWebKit || !capabilities.isAppleMobile) {
    return;
  }

  const hasPreventers = globalState.preventers.size > 0;

  if (hasPreventers) {
    if (!globalState.cleanup) {
      globalState.cleanup = setupGlobalListeners();
    }
  } else {
    if (globalState.cleanup) {
      globalState.cleanup();
      globalState.cleanup = null;
    }
  }
}

/**
 * Modifier to prevent the browser's native scroll-into-view behavior
 * when text inputs receive focus inside a scroll container.
 *
 * On WebKit iOS/iPadOS: Uses clone technique for certain inputs.
 * Uses global document-level event listeners (singleton pattern).
 *
 * @param {HTMLElement} scrollContainer - The scroll container element
 * @param {boolean} enabled - Whether prevention is enabled
 */
export default modifier((scrollContainer, [enabled]) => {
  if (!enabled) {
    return;
  }

  scrollContainer.setAttribute("data-d-scroll-focus-prevention", "true");
  const preventerId = registerPreventer();

  return () => {
    scrollContainer.removeAttribute("data-d-scroll-focus-prevention");
    unregisterPreventer(preventerId);
  };
});
