import deprecated from "discourse-common/lib/deprecated";

export function getOwner(obj) {
  if (Ember.getOwner) {
    return Ember.getOwner(obj) || Discourse.__container__;
  }

  return obj.container;
}

// `this.container` is deprecated, but we can still build a container-like
// object for components to use
export function getRegister(obj) {
  const owner = getOwner(obj);
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
            "Use `this.register` or `getOwner` instead of `this.container`"
          );
          return register;
        }
      });
    }
  };

  return register;
}
