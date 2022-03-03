import { helperContext } from "discourse-common/lib/helpers";
import positioningWorkaround from "discourse/lib/safari-hacks";

export default function (element) {
  const caps = helperContext().capabilities;

  if (caps.isApple && positioningWorkaround.touchstartEvent) {
    positioningWorkaround.touchstartEvent(element);
  } else {
    element.focus();
  }

  const len = element.value.length;
  element.setSelectionRange(len, len);

  // Scroll to the bottom, in case we're in a tall textarea
  element.scrollTop = 999999;
}
