import { later } from "@ember/runloop";

export function setupComposerPosition(editor) {
  // This component contains two composer positioning adjustments
  // for Safari iOS/iPad and Firefox on Android
  // The fixes here go together with styling in base/compose.css
  const html = document.documentElement;

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
  // the body so that the input/textarea is centered
  // This pushes the fixed element offscreen
  // Here we detect when the composer's top position is above the window's
  // current scroll offset and correct it
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
}

function editorTouchMove(event) {
  // This is an alternative to locking up the body
  // It stops scrolling in the given element from bubbling up to the body
  // when the textarea does not have any content to scroll
  if (event.target) {
    const notScrollable =
      event.target.scrollHeight <= event.target.clientHeight;
    if (notScrollable) {
      event.preventDefault();
      event.stopPropagation();
    }
  }
}
