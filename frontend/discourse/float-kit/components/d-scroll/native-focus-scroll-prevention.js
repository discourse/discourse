import { modifier } from "ember-modifier";
import { isCloneElement } from "discourse/float-kit/lib/utils";
import { isKeyboardVisible } from "discourse/lib/utilities";
import { capabilities } from "discourse/services/capabilities";
import {
  findClosestFocusPreventionContainer,
  isColorOrSelect,
  isInsidePreventionContainer,
  isNearViewportBottom,
  isPasswordRelatedInput,
} from "./focus-scroll-utils";
import isTextInput from "./is-text-input";

const globalState = {
  preventers: new Map(),
  pendingFocusJobs: new Map(),
  cleanup: null,
  idCounter: 0,
};

function generatePreventerId() {
  return `d-scroll-focus-prevention-${++globalState.idCounter}`;
}

function cancelPendingFocusJob(focusPreventionContainer) {
  const job = globalState.pendingFocusJobs.get(focusPreventionContainer);

  if (!job) {
    return;
  }

  clearTimeout(job.timeout);
  job.clone.remove();
  globalState.pendingFocusJobs.delete(focusPreventionContainer);
}

function cancelAllPendingFocusJobs() {
  for (const job of globalState.pendingFocusJobs.values()) {
    clearTimeout(job.timeout);
    job.clone.remove();
  }

  globalState.pendingFocusJobs.clear();
}

function schedulePendingFocusJob(
  focusPreventionContainer,
  relatedTarget,
  clone
) {
  cancelPendingFocusJob(focusPreventionContainer);

  const job = {
    clone,
    timeout: setTimeout(() => {
      if (globalState.pendingFocusJobs.get(focusPreventionContainer) !== job) {
        return;
      }

      globalState.pendingFocusJobs.delete(focusPreventionContainer);

      try {
        if (
          relatedTarget.isConnected &&
          findClosestFocusPreventionContainer(relatedTarget) ===
            focusPreventionContainer &&
          isInsidePreventionContainer(relatedTarget)
        ) {
          relatedTarget.focus({ preventScroll: true });
        }
      } finally {
        clone.remove();
      }
    }, 32),
  };

  globalState.pendingFocusJobs.set(focusPreventionContainer, job);
}

function setupGlobalListeners() {
  const handleTouchStart = (event) => {
    const target = event.target;
    if (isInsidePreventionContainer(target)) {
      const focusPreventionContainer =
        findClosestFocusPreventionContainer(target);
      focusPreventionContainer?.focus({ preventScroll: true });
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

    const focusPreventionContainer =
      findClosestFocusPreventionContainer(relatedTarget);

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
      clone.focus({ preventScroll: true });
      schedulePendingFocusJob(focusPreventionContainer, relatedTarget, clone);
    } else {
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
      const focusPreventionContainer =
        findClosestFocusPreventionContainer(target);
      focusPreventionContainer?.focus({ preventScroll: true });
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
    cancelAllPendingFocusJobs();
  };
}

function registerPreventer(focusPreventionContainer) {
  const id = generatePreventerId();
  globalState.preventers.set(id, focusPreventionContainer);
  processPreventersChanges();
  return id;
}

function unregisterPreventer(id) {
  const focusPreventionContainer = globalState.preventers.get(id);
  globalState.preventers.delete(id);
  cancelPendingFocusJob(focusPreventionContainer);
  processPreventersChanges();
}

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

export default modifier((focusPreventionContainer, [enabled]) => {
  if (!enabled) {
    return;
  }

  focusPreventionContainer.setAttribute(
    "data-d-scroll-focus-prevention",
    "true"
  );
  const preventerId = registerPreventer(focusPreventionContainer);

  return () => {
    focusPreventionContainer.removeAttribute("data-d-scroll-focus-prevention");
    unregisterPreventer(preventerId);
  };
});
