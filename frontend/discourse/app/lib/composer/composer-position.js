import { later } from "@ember/runloop";
import { lock, unlock } from "discourse/lib/body-scroll-lock";
import { applyBehaviorTransformer } from "discourse/lib/transformer";

export function setupComposerPosition(
  editor,
  { swipeToCollapse = false } = {}
) {
  // This component contains two composer positioning adjustments
  // for Safari iOS/iPad and Firefox on Android
  // The fixes here go together with styling in base/compose.css
  const html = document.documentElement;
  const isMobileOrIpad =
    html.classList.contains("mobile-device") ||
    html.classList.contains("ipados-device");
  const isIOS = html.classList.contains("ios-device");
  const isIpadOS = html.classList.contains("ipados-device");

  let editorFocused = document.activeElement === editor;
  let scrollLocked = false;
  let scrollLockTargets = null;

  function shouldLockScroll() {
    const ipadHardwareKeyboard =
      isIpadOS && !html.classList.contains("keyboard-visible");
    return editorFocused && isIOS && !ipadHardwareKeyboard;
  }

  function getAllowedScrollTargets() {
    const replyControl = document.getElementById("reply-control");
    return [
      editor,
      replyControl?.querySelector(".d-editor-preview-wrapper"),
      replyControl?.querySelector(".d-editor-button-bar"),
    ].filter(Boolean);
  }

  function selectionTouchmoveGuard(event) {
    if (editor.selectionStart !== editor.selectionEnd) {
      event.stopImmediatePropagation();
    }
  }

  function refreshScrollLock() {
    if (shouldLockScroll() && !scrollLocked) {
      scrollLockTargets = getAllowedScrollTargets();
      editor.addEventListener("touchmove", selectionTouchmoveGuard, {
        capture: true,
        passive: false,
      });
      lock(scrollLockTargets);
      scrollLocked = true;
    } else if (!shouldLockScroll() && scrollLocked) {
      editor.removeEventListener("touchmove", selectionTouchmoveGuard, {
        capture: true,
      });
      unlock(scrollLockTargets);
      scrollLockTargets = null;
      scrollLocked = false;
    }
  }

  function onFocus() {
    editorFocused = true;
    refreshScrollLock();
  }

  function onBlur() {
    editorFocused = false;
    refreshScrollLock();
  }

  function editorTouchMove(event) {
    // This is an alternative to locking up the body
    // It stops scrolling in the given element from bubbling up to the body
    // when the editor does not have any content to scroll
    applyBehaviorTransformer("composer-position:editor-touch-move", () => {
      const notScrollable = editor.scrollHeight <= editor.clientHeight;
      const selection = window.getSelection();
      if (notScrollable && selection.toString() === "") {
        event.preventDefault();

        // stopPropagation would swallow the composer's swipe-to-dismiss gesture
        // on an ancestor; preventDefault alone still blocks the body scroll
        if (!swipeToCollapse) {
          event.stopPropagation();
        }
      }
    });
  }

  let classObserver;
  if (isMobileOrIpad) {
    window.addEventListener("scroll", correctScrollPosition);
    correctScrollPosition();
    editor.addEventListener("touchmove", editorTouchMove);
  }

  if (isIOS) {
    editor.addEventListener("focus", onFocus);
    editor.addEventListener("blur", onBlur);
    refreshScrollLock();
  }

  if (isIpadOS) {
    classObserver = new MutationObserver(refreshScrollLock);
    classObserver.observe(html, {
      attributes: true,
      attributeFilter: ["class"],
    });
  }

  // destructor
  return () => {
    if (isMobileOrIpad) {
      window.removeEventListener("scroll", correctScrollPosition);
      editor.removeEventListener("touchmove", editorTouchMove);
    }

    if (isIOS) {
      editor.removeEventListener("focus", onFocus);
      editor.removeEventListener("blur", onBlur);

      if (scrollLocked) {
        editor.removeEventListener("touchmove", selectionTouchmoveGuard, {
          capture: true,
        });
        unlock(scrollLockTargets);
        scrollLockTargets = null;
        scrollLocked = false;
      }
    }

    if (isIpadOS) {
      classObserver?.disconnect();
    }
  };
}

function correctScrollPosition() {
  // In some rare cases, when quoting a large text or
  // when editing a long topic, Safari/Firefox will scroll
  // the body so that the editor is centered
  // This pushes the fixed element offscreen
  // Here we detect when the composer's top position is above the window's
  // current scroll offset and correct it
  applyBehaviorTransformer("composer-position:correct-scroll-position", () => {
    later(() => {
      const el = document.querySelector("#reply-control");
      const rect = el.getBoundingClientRect();
      if (rect.top < -1) {
        const scrollAmount = window.scrollY + rect.top;
        window.scrollTo({
          top: scrollAmount,
          behavior: "instant",
        });
      }
    }, 150);
  });
}
