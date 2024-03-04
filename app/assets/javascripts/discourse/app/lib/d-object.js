import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/application";
import ApplicationInstance from "@ember/application/instance";
import { getOwner } from "@ember/owner";

const ATTRS = new WeakMap();

export default class DObject {
  static get attrs() {
    const keys = [];
    let klass = this;
    while (klass) {
      const attrs = ATTRS.get(klass);
      if (attrs) {
        keys.push(...attrs.keys());
      }
      klass = Object.getPrototypeOf(klass);
    }
    return keys;
  }

  constructor(owner, attrs) {
    if (owner && !(owner instanceof ApplicationInstance)) {
      throw new Error(
        "First argument of BaseModel constructor must be the owning ApplicationInstance"
      );
    }
    setOwner(this, owner);
    this.setAttrs(attrs);
  }

  /**
   * Set attributes, ignoring any properties which do not match
   * an `@attr` of this object.
   */
  setAttrs(attrs) {
    for (const key of this.constructor.attrs) {
      if (key in attrs) {
        this[key] = attrs[key];
      }
    }
  }
}

/**
 * Class decorator which adds shims for the most common EmberObject functions:
 *   - get
 *   - set
 *   - getProperties
 *   - setProperties
 *   - create
 */
export function emberObjectCompat(target) {
  Object.assign(target.prototype, {
    get(key) {
      if (key.includes(".")) {
        throw "no nested keys"; // TODO?
      }
      return this[key];
    },
    set(key, value) {
      if (key.includes(".")) {
        throw "no nested keys"; // TODO?
      }
      this[key] = value;
    },
    setProperties(obj) {
      if (Object.keys(obj).some((key) => key.includes("."))) {
        throw "no nested keys"; // TODO?
      }
      Object.assign(this, obj);
    },
    getProperties(...keys) {
      const result = {};
      for (const key of keys) {
        if (key.includes(".")) {
          throw "no nested keys"; // TODO?
        }
        result[key] = this[key];
      }
      return result;
    },
  });

  target.create = function (props) {
    return new target(getOwner(props), props);
  };
}

function throwIfNotDObject(klass) {
  while (klass) {
    if (klass === DObject) {
      return;
    }
    klass = Object.getPrototypeOf(klass);
  }
  throw new Error("This decorator can only be used on a DObject");
}

/**
 * Decorator for defining an attribute on a DObject. Attributes
 * are tracked properties which are set via arguments to the constructor.
 */
export function attr(target, key, descriptor) {
  throwIfNotDObject(target.constructor);

  let attrs = ATTRS.get(target.constructor);
  if (!attrs) {
    attrs = new Map();
    ATTRS.set(target.constructor, attrs);
  }
  attrs.set(key, {});

  if (!descriptor.get && !descriptor.set) {
    return tracked(...arguments);
  }
  // return descriptor;
}
