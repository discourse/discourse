import { setInternalHelperManager } from "@glimmer/manager";
import { createConstRef, valueForRef } from "@glimmer/reference";

// Like ember's builtin hash helper, but instead of returning a reified object
// every time its referenced, it returns a static proxy object with auto-trackable keys.
export default setInternalHelperManager(({ named }) => {
  const proxy = new Proxy(named, {
    get(target, prop) {
      if (target[prop]) {
        return valueForRef(target[prop]);
      }
    },
    isExtensible() {
      return false;
    },
    getOwnPropertyDescriptor(target, key) {
      if (key in target) {
        return {
          enumerable: true,
          configurable: true,
          get() {
            if (target[key]) {
              return valueForRef(target[key]);
            }
          },
        };
      }
    },
    set() {
      return false;
    },
  });

  return createConstRef(proxy);
}, {});
