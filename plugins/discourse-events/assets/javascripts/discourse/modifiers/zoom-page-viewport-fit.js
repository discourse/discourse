import { cancel } from "@ember/runloop";
import { modifier } from "ember-modifier";
import discourseDebounce from "discourse/lib/debounce";

// The viewport is resized repeatedly while the keyboard animates, and every one
// of those is a size the page should not be laid out at.
const SETTLE_DELAY = 50;

// Long enough after a keyboard arrives for it to have taken its space and the
// page to have been laid out around it, and equally for one to have finished
// leaving.
const KEYBOARD_SETTLE_DELAY = 400;

function isTextEntry(node) {
  return !!node?.matches?.("input, textarea, [contenteditable='true']");
}

// The meeting and chat divide up exactly what the viewport is showing, which
// only measuring can establish: the header and whatever spacing the layout
// applies above them all come out of the height they have to share.
//
// The measurements are published as custom properties for the stylesheet to lay
// the page out from, and a keyboard is announced with an attribute. Scrolling
// is left alone but for putting the composer in view when one opens.
export default modifier((element) => {
  const viewport = window.visualViewport;

  if (!viewport) {
    return;
  }

  // Whether the composer holds focus is the one signal for the keyboard that
  // cannot feed back into itself. Measuring the keyboard against the window
  // instead does: anything that scrolls the page retracts the browser's
  // toolbars, which resizes the viewport, which reads as the keyboard closing.
  let editing = false;
  let restingViewportHeight = viewport.height;
  let hasScrolledToComposer = false;
  let resizeHandler = null;
  let composerHandler = null;
  let settleHandler = null;

  // With a keyboard up the page becomes a scroller of its own, pinned over what
  // is visible, and this puts the composer at the end of it. Scrolling the
  // page's own contents is what makes the position reliable: the document's
  // scrolling stops at the layout viewport, which the keyboard is allowed to
  // overlap, so its end can never reach the keyboard's top edge.
  const showComposer = () => {
    composerHandler = null;

    if (editing) {
      element.scrollTop = element.scrollHeight;
    }
  };

  const apply = () => {
    // Held across keyboard states: the meeting is sized from it, and
    // remeasuring while a keyboard covers part of the page would resize the
    // meeting to fit what is left, which is the one thing this is meant to
    // avoid.
    if (!editing) {
      restingViewportHeight = viewport.height;
    }

    const keyboardHeight = Math.max(0, restingViewportHeight - viewport.height);
    const keyboardIsOpen = editing && keyboardHeight > 0;

    // Announced before anything is measured against it. A keyboard takes the
    // page out of the document's flow and gives it back afterwards, and an
    // offset read while it is still in the arrangement it is leaving describes
    // where the page was rather than where it is about to be.
    //
    // A data attribute rather than a class: the class attribute belongs to the
    // template, which would drop anything set on it here the next time it
    // renders.
    if (keyboardIsOpen) {
      element.dataset.keyboardOpen = "true";
    } else {
      delete element.dataset.keyboardOpen;
    }

    const offsetFromDocumentTop =
      element.getBoundingClientRect().top + window.scrollY;
    const resting = restingViewportHeight - offsetFromDocumentTop;

    element.style.setProperty(
      "--livestream-zoom-resting-height",
      `${resting}px`
    );
    element.style.setProperty(
      "--livestream-zoom-visible-height",
      `${viewport.height}px`
    );

    // Where the visible area begins within the viewport a fixed element is
    // positioned against. A keyboard can leave the two with different tops.
    element.style.setProperty(
      "--livestream-zoom-visible-top",
      `${viewport.offsetTop}px`
    );

    if (keyboardIsOpen && !hasScrolledToComposer) {
      hasScrolledToComposer = true;
      composerHandler = discourseDebounce(showComposer, KEYBOARD_SETTLE_DELAY);
    }

    if (!keyboardIsOpen) {
      cancel(composerHandler);
      composerHandler = null;
      hasScrolledToComposer = false;
    }
  };

  const onViewportResize = () => {
    resizeHandler = discourseDebounce(apply, SETTLE_DELAY);
  };

  const onFocusChange = (event) => {
    if (!isTextEntry(event.target)) {
      return;
    }

    editing = event.type === "focusin";
    apply();

    // A keyboard on its way out resizes the viewport as it goes, and the last
    // of those can still arrive before it has finished: the page would be
    // measured against a viewport that is still growing, and nothing would come
    // afterwards to correct it. One more measurement once it is done settles
    // the page at the size it actually ended up with.
    if (!editing) {
      settleHandler = discourseDebounce(apply, KEYBOARD_SETTLE_DELAY);
    }
  };

  apply();

  viewport.addEventListener("resize", onViewportResize);
  window.addEventListener("orientationchange", onViewportResize);
  element.addEventListener("focusin", onFocusChange);
  element.addEventListener("focusout", onFocusChange);

  return () => {
    cancel(resizeHandler);
    cancel(composerHandler);
    cancel(settleHandler);
    viewport.removeEventListener("resize", onViewportResize);
    window.removeEventListener("orientationchange", onViewportResize);
    element.removeEventListener("focusin", onFocusChange);
    element.removeEventListener("focusout", onFocusChange);
  };
});
