import { setInternalHelperManager } from "@glimmer/manager";
import { createConstRef } from "@glimmer/reference";

// Like ember's builtin hash helper, but instead of returning a reified object
// every time its referenced, it returns a static proxy object with auto-trackable keys.
export default setInternalHelperManager(({ named }) => {
  const proxy = new Proxy(named, {
    get(target, prop) {
      return target[prop]?.compute();
    },
  });

  return createConstRef(proxy);
}, {});
