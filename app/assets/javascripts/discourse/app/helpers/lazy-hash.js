import { setInternalHelperManager } from "@glimmer/manager";
import { createComputeRef, valueForRef } from "@glimmer/reference";
import { dependentKeyCompat } from "@ember/object/compat";

class LazyHash {
  constructor(namedRefs) {
    for (const [key, value] of Object.entries(namedRefs)) {
      Object.defineProperty(
        this,
        key,
        dependentKeyCompat(this, key, {
          get() {
            return valueForRef(value);
          },
          enumerable: true,
          configurable: false,
        })
      );
    }
    Object.preventExtensions(this);
  }
}

// Like ember's builtin hash helper, but instead of returning a reified object
// every time its referenced, it returns a static proxy object with auto-trackable keys.
export default setInternalHelperManager(({ named: namedRefs }) => {
  let instance;
  return createComputeRef(
    () => (instance ??= new LazyHash(namedRefs)),
    null,
    "lazy-hash"
  );
}, {});
