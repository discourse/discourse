import extractValue from "./utils/extract-value";

export default function decoratorAlias(fn, errorMessage) {
  return function(...params) {
    // determine if user called as @discourseComputed('blah', 'blah') or @discourseComputed
    if (params.length === 0) {
      throw new Error(errorMessage);
    } else {
      return function(target, key, desc) {
        return {
          enumerable: desc.enumerable,
          configurable: desc.configurable,
          writable: desc.writable,
          initializer: function() {
            var value = extractValue(desc);
            return fn.apply(null, params.concat(value));
          }
        };
      };
    }
  };
}
