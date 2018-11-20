import isDescriptor from "./utils/is-descriptor";

function handleDescriptor(target, property, desc, fn, params = []) {
  return {
    enumerable: desc.enumerable,
    configurable: desc.configurable,
    writable: desc.writable,
    initializer: function() {
      return fn(...params);
    }
  };
}

export default function macroAlias(fn) {
  return function(...params) {
    if (isDescriptor(params[params.length - 1])) {
      return handleDescriptor(...params, fn);
    } else {
      return function(target, property, desc) {
        return handleDescriptor(target, property, desc, fn, params);
      };
    }
  };
}
