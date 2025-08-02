import deprecated from "discourse/lib/deprecated";
import isDescriptor from "discourse/lib/is-descriptor";

function handleDescriptor(target, property, desc, fn, params = []) {
  return {
    enumerable: desc.enumerable,
    configurable: desc.configurable,
    writable: desc.writable,
    initializer() {
      return fn(...params);
    },
  };
}

export default function macroAlias(fn) {
  return function (...params) {
    if (isDescriptor(params[params.length - 1])) {
      return handleDescriptor(...params, fn);
    } else {
      deprecated(
        `Importing ${fn.name} from 'discourse/lib/decorators' is deprecated. You should instead import it from '@ember/object/computed' directly.`,
        { id: "discourse.utils-decorators-import" }
      );
      return function (target, property, desc) {
        return handleDescriptor(target, property, desc, fn, params);
      };
    }
  };
}
