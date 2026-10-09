import { modifier } from "ember-modifier";

export default modifier((element) => {
  const onClick = (event) => {
    if (!event.target.closest("button.-send")) {
      return;
    }

    // Only a keyboard that is covering the meeting is worth giving focus up
    // for. The page's own attribute rather than core's `keyboard-visible`
    // class: that is set from the window's height against the viewport's, which
    // only part company on a browser that lets the keyboard overlay the page.
    // Android shrinks the window to fit one, leaving the class unset.
    if (!element.closest("[data-keyboard-open]")) {
      return;
    }

    element.querySelector(".chat-composer__input")?.blur();
  };

  element.addEventListener("click", onClick);

  return () => element.removeEventListener("click", onClick);
});
