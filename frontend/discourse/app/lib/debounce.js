import { debounce } from "@ember/runloop";
import { isTesting } from "discourse/lib/environment";

/**
  Debounce a Javascript function. This means if it's called many times in a time limit it
  should only be executed once (at the end of the limit counted from the last call made).
  Original function will be called with the context and arguments from the last call made.
**/

export default function (...params) {
  if (isTesting()) {
    const lastArgument = params[params.length - 1];
    const hasImmediateArgument = typeof lastArgument === "boolean";

    let args = [].slice.call(params, 0, hasImmediateArgument ? -2 : -1);

    // Replace the time argument with 10ms
    args.push(10);

    if (hasImmediateArgument) {
      args.push(lastArgument);
    }

    return debounce.apply(undefined, args);
  } else {
    return debounce(...params);
  }
}
