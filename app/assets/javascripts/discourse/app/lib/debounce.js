import { debounce } from "@ember/runloop";
import { isTesting } from "discourse/lib/environment";

/**
  Debounce a Javascript function. This means if it's called many times in a time limit it
  should only be executed once (at the end of the limit counted from the last call made).
  Original function will be called with the context and arguments from the last call made.
**/

export default function discourseDebounce() {
  if (isTesting()) {
    const lastArgument = arguments[arguments.length - 1];
    const hasImmediateArgument = typeof lastArgument === "boolean";

    let args = [].slice.call(arguments, 0, hasImmediateArgument ? -2 : -1);

    // Replace the time argument with 10ms
    args.push(10);

    if (hasImmediateArgument) {
      args.push(lastArgument);
    }

    return debounce.apply(undefined, args);
  } else {
    return debounce(...arguments);
  }
}

const promiseInfos = new WeakMap();

/**
 * Create a promise whos resolution will be debounced.
 * Only the last promise will be resolved - others will
 * be discarded without resolution or rejection.
 */
export function debouncePromise(identifier, timeout) {
  let info = promiseInfos.get(identifier);
  if (!info) {
    info = {
      debounceFn: () => {
        promiseInfos.get(identifier).resolve();
        promiseInfos.delete(identifier);
      },
    };
    promiseInfos.set(identifier, info);
  }
  const promise = new Promise((resolve) => (info.resolve = resolve));
  discourseDebounce(info.debounceFn, timeout);
  return promise;
}
