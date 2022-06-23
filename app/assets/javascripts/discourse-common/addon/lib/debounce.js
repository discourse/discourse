import { debounce } from "@ember/runloop";
import { isTesting } from "discourse-common/config/environment";

/**
  Debounce a Javascript function. This means if it's called many times in a time limit it
  should only be executed once (at the end of the limit counted from the last call made).
  Original function will be called with the context and arguments from the last call made.
**/

export default function () {
  if (isTesting()) {
    // Replace the time argument with 10ms
    let args = [].slice.call(arguments, 0, -1);
    args.push(10);

    return debounce.apply(undefined, args);
  } else {
    return debounce(...arguments);
  }
}
