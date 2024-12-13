import { helperContext } from "discourse-common/lib/helpers";

export default function (element) {
  const caps = helperContext().capabilities;

  const len = element.value.length;

  // don't scroll to end of element with a lot of text in iOS
  // it causes composer container to go out of viewport
  if (caps.isIOS && element.tagName === "TEXTAREA" && len > 150) {
    return;
  }

  element.focus();

  element.setSelectionRange(len, len);

  // Scroll to the bottom, in case we're in a tall textarea
  element.scrollTop = 999999;
}
