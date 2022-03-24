import { debounce } from "@ember/runloop";
/**
  Debounce a Javascript function. This means if it's called many times in a time limit it
  should only be executed once (at the end of the limit counted from the last call made).
  Original function will be called with the context and arguments from the last call made.
**/
export default function (func, wait) {
  let args;
  const later = () => {
    func.apply(this, args);
  };

  return function () {
    args = arguments;

    debounce(null, later, wait);
  };
}
