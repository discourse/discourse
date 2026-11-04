import { getOwner as emberGetOwner, setOwner } from "@ember/owner";

export { getOwner } from "@ember/owner";

let _default = {};

/**
 * Works similarly to { getOwner } from `@ember/owner`, but has a fallback
 * when the passed object doesn't have an owner.
 *
 * This exists for historical reasons. Ideally, any uses of it should be updated to use
 * the official `@ember/owner` implementation.
 */
export function getOwnerWithFallback(obj) {
  if (emberGetOwner) {
    return emberGetOwner(obj || _default) || emberGetOwner(_default);
  }

  return obj.container;
}

export function setDefaultOwner(container) {
  setOwner(_default, container);
}

// Builds a container-like object for components to use
export function getRegister(obj) {
  const owner = getOwnerWithFallback(obj);
  const register = {
    lookup: (...args) => owner.lookup(...args),
    lookupFactory: (...args) => {
      if (owner.factoryFor) {
        return owner.factoryFor(...args);
      } else if (owner._lookupFactory) {
        return owner._lookupFactory(...args);
      }
    },
  };

  setOwner(register, owner);

  return register;
}
