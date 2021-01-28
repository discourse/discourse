import { debounce, next, run } from "@ember/runloop";
import { isLegacyEmber, isTesting } from "discourse-common/config/environment";

/**
  Debounce a Javascript function. This means if it's called many times in a time limit it
  should only be executed once (at the end of the limit counted from the last call made).
  Original function will be called with the context and arguments from the last call made.
**/

let testingFunc = isLegacyEmber() ? run : next;

export default function () {
  if (isTesting()) {
    return testingFunc(...arguments);
  } else {
    return debounce(...arguments);
  }
}
