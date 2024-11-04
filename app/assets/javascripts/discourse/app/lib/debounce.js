import { debounce } from "@ember/runloop";
import deprecated from "discourse-common/lib/deprecated";

/**
  Debounce a Javascript function. This means if it's called many times in a time limit it
  should only be executed once (at the end of the limit counted from the last call made).
  Original function will be called with the context and arguments from the last call made.
**/
export default function (func, wait) {
  deprecated(
    "Importing from `discourse/lib/debounce` is deprecated. Import from `discourse-common/lib/debounce` instead.",
    {
      id: "discourse.discourse-debounce",
      since: "3.4.0.beta3-dev",
    }
  );

  let args;
  const later = () => {
    func.apply(this, args);
  };

  return function () {
    args = arguments;

    debounce(null, later, wait);
  };
}
