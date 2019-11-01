import { throttle } from "@ember/runloop";
/**
  Throttle a Javascript function. This means if it's called many times in a time limit it
  should only be executed one time at most during this time limit
  Original function will be called with the context and arguments from the last call made.
**/
export default function(func, spacing, immediate) {
  let self, args;
  const later = function() {
    func.apply(self, args);
  };

  return function() {
    self = this;
    args = arguments;

    throttle(null, later, spacing, immediate);
  };
}
