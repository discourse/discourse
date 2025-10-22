import { getOwner as emberGetOwner, setOwner } from "@ember/owner";
import deprecated from "discourse/lib/deprecated";

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

/**
 * @deprecated use `getOwnerWithFallback` instead
 */
export function getOwner(obj) {
  deprecated(
    "Importing getOwner from `discourse/lib/get-owner` is deprecated. See the alternatives on meta.",
    {
      since: "3.2",
      id: "discourse.get-owner-with-fallback",
      url: "https://meta.discourse.org/t/292080",
    }
  );
  return getOwnerWithFallback(obj);
}

export function setDefaultOwner(container) {
  setOwner(_default, container);
}

// `this.container` is deprecated, but we can still build a container-like
// object for components to use
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

    deprecateContainer(target) {
      Object.defineProperty(target, "container", {
        get() {
          deprecated(
            "Use `this.register` or `getOwner` instead of `this.container`",
            { id: "discourse.this-container" }
          );
          return register;
        },
      });
    },
  };

  setOwner(register, owner);

  return register;
}
