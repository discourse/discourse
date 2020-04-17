import positioningWorkaround from "discourse/lib/safari-hacks";
import { isAppleDevice } from "discourse/lib/utilities";

export default function(element) {
  if (isAppleDevice() && positioningWorkaround.touchstartEvent) {
    positioningWorkaround.touchstartEvent(element);
  } else {
    element.focus();
  }

  const len = element.value.length;
  element.setSelectionRange(len, len);

  // Scroll to the bottom, in case we're in a tall textarea
  element.scrollTop = 999999;
}
