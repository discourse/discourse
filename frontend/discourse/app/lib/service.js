import { registerDestructor } from "@ember/destroyable";
import { getOwner, setOwner } from "@ember/owner";
import EmberService, { service as emberService } from "@ember/service";
import {
  lookup as polarisLookup,
  setServiceManager,
} from "ember-polaris-service";

// Discourse hands out both application instances and their containers as
// owners; polaris keys services by scope, so both have to map to the instance.
export function scopeFor(ownerLike) {
  if (ownerLike?.registry && ownerLike.owner) {
    return ownerLike.owner;
  }
  return ownerLike;
}

export function lookup(ownerLike, factory) {
  return polarisLookup(scopeFor(ownerLike), factory);
}

const classicManager = (scope) => ({
  createService(Klass) {
    const props = {};
    setOwner(props, scope);
    const instance = EmberService.create.call(Klass, props);
    registerDestructor(scope, () => instance.destroy());
    return instance;
  },
});

// A classic Ember service that polaris can instantiate. A string lookup on the
// container reaches the same instance as an injection.
export default class Service extends EmberService {
  static create(props) {
    return lookup(getOwner(props), this);
  }
}

setServiceManager(classicManager, Service);

// Gives a class with its own `static build(props)` the same dual identity.
export function serviceFactory(Klass) {
  setServiceManager(
    (scope) => ({
      createService(K) {
        const props = {};
        setOwner(props, scope);
        const instance = K.build(props);
        return instance;
      },
    }),
    Klass
  );
  Klass.create = function (props) {
    return lookup(getOwner(props), this);
  };
  return Klass;
}

function injected(resolve) {
  return function (target, key) {
    return {
      configurable: true,
      enumerable: false,
      get() {
        const value = lookup(getOwner(this) ?? this.container, resolve());
        Object.defineProperty(this, key, {
          value,
          configurable: true,
          writable: true,
        });
        return value;
      },
      set(value) {
        Object.defineProperty(this, key, {
          value,
          configurable: true,
          writable: true,
        });
      },
    };
  };
}

// `@service(() => Foo) foo` injects an imported service. The thunk keeps
// import cycles between a service and its consumers safe. `@service foo` and
// `@service("name") foo` still reach the container by name.
export function service(...args) {
  if (args.length === 1 && typeof args[0] === "function") {
    return injected(args[0]);
  }
  return emberService(...args);
}
