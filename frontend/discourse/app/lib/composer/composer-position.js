import { later } from "@ember/runloop";
import { applyBehaviorTransformer } from "discourse/lib/transformer";

export function setupComposerPosition(editor) {
  // This component contains two composer positioning adjustments
  // for Safari iOS/iPad and Firefox on Android
  // The fixes here go together with styling in base/compose.css
  const html = document.documentElement;

  function editorTouchMove(event) {
    // This is an alternative to locking up the body
    // It stops scrolling in the given element from bubbling up to the body
    // when the editor does not have any content to scroll
    applyBehaviorTransformer("composer-position:editor-touch-move", () => {
      const notScrollable = editor.scrollHeight <= editor.clientHeight;
      const selection = window.getSelection();
      if (notScrollable && selection.toString() === "") {
        event.preventDefault();
        event.stopPropagation();
      }
    });
  }

  if (
    html.classList.contains("mobile-device") ||
    html.classList.contains("ipados-device")
  ) {
    window.addEventListener("scroll", correctScrollPosition);
    correctScrollPosition();
    editor.addEventListener("touchmove", editorTouchMove);
  }

  // destructor
  return () => {
    if (
      html.classList.contains("mobile-device") ||
      html.classList.contains("ipados-device")
    ) {
      window.removeEventListener("scroll", correctScrollPosition);
      editor.removeEventListener("touchmove", editorTouchMove);
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
