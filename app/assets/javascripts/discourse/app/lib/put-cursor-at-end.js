import { helperContext } from "discourse-common/lib/helpers";

export default function (element) {
  const caps = helperContext().capabilities;

  if (caps.isIOS) {
    return;
  }

  element.focus();

  const len = element.value.length;
  element.setSelectionRange(len, len);

  // Scroll to the bottom, in case we're in a tall textarea
  element.scrollTop = 999999;
}
