import Component from "@glimmer/component";
import { later } from "@ember/runloop";

export default class DComposerPosition extends Component {
  // This component contains two composer positioning adjustments
  // for Safari iOS/iPad and Firefox on Android
  // The fixes here go together with styling in base/compose.css
  constructor() {
    super(...arguments);

    if (!window.visualViewport) {
      return;
    }

    const html = document.documentElement;

    if (
      html.classList.contains("ios-device") ||
      html.classList.contains("ipados-device")
    ) {
      window.addEventListener("scroll", this._correctScrollPosition);
      this._correctScrollPosition();

      const editor = document.querySelector(".d-editor-input");
      editor?.addEventListener("touchmove", this._textareaTouchMove);
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (!window.visualViewport) {
      return;
    }

    const html = document.documentElement;

    if (
      html.classList.contains("mobile-device") ||
      html.classList.contains("ipados-device")
    ) {
      window.removeEventListener("scroll", this._correctScrollPosition);
      const editor = document.querySelector(".d-editor-input");
      editor?.removeEventListener("touchmove", this._textareaTouchMove);
    }
  }

  _correctScrollPosition() {
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

  _textareaTouchMove(event) {
    // This is an alternative to locking up the body
    // It stops scrolls from bubbling up to the body
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
}
