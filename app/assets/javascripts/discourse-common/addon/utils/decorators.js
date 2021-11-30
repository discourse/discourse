import { bind as emberBind, schedule } from "@ember/runloop";
import decoratorAlias from "discourse-common/utils/decorator-alias";
import extractValue from "discourse-common/utils/extract-value";
import handleDescriptor from "discourse-common/utils/handle-descriptor";
import isDescriptor from "discourse-common/utils/is-descriptor";
import macroAlias from "discourse-common/utils/macro-alias";

export default function discourseComputedDecorator(...params) {
  // determine if user called as @discourseComputed('blah', 'blah') or @discourseComputed
  if (isDescriptor(params[params.length - 1])) {
    return handleDescriptor(...arguments);
  } else {
    return function (/* target, key, desc */) {
      return handleDescriptor(...arguments, params);
    };
  }
}

export function afterRender(target, name, descriptor) {
  const originalFunction = descriptor.value;
  descriptor.value = function () {
    schedule("afterRender", () => {
      if (this.element && !this.isDestroying && !this.isDestroyed) {
        return originalFunction.apply(this, arguments);
      }
    });
  };
}

export function bind(target, name, descriptor) {
  return {
    configurable: true,
    get() {
      const bound = emberBind(this, descriptor.value);
      const attributes = Object.assign({}, descriptor, {
        value: bound,
      });

      Object.defineProperty(this, name, attributes);

      return bound;
    },
  };
}

export function readOnly(target, name, desc) {
  return {
    writable: false,
    enumerable: desc.enumerable,
    configurable: desc.configurable,
    initializer() {
      let value = extractValue(desc);
      return value.readOnly();
    },
  };
}

/* eslint-disable */
export var on = decoratorAlias(Ember.on, "Can not `on` without event names");
export var observes = decoratorAlias(
  Ember.observer,
  "Can not `observe` without property names"
);

export var alias = macroAlias(Ember.computed.alias);
export var and = macroAlias(Ember.computed.and);
export var bool = macroAlias(Ember.computed.bool);
export var collect = macroAlias(Ember.computed.collect);
export var empty = macroAlias(Ember.computed.empty);
export var equal = macroAlias(Ember.computed.equal);
export var filter = macroAlias(Ember.computed.filter);
export var filterBy = macroAlias(Ember.computed.filterBy);
export var gt = macroAlias(Ember.computed.gt);
export var gte = macroAlias(Ember.computed.gte);
export var lt = macroAlias(Ember.computed.lt);
export var lte = macroAlias(Ember.computed.lte);
export var map = macroAlias(Ember.computed.map);
export var mapBy = macroAlias(Ember.computed.mapBy);
export var match = macroAlias(Ember.computed.match);
export var max = macroAlias(Ember.computed.max);
export var min = macroAlias(Ember.computed.min);
export var none = macroAlias(Ember.computed.none);
export var not = macroAlias(Ember.computed.not);
export var notEmpty = macroAlias(Ember.computed.notEmpty);
export var oneWay = macroAlias(Ember.computed.oneWay);
export var or = macroAlias(Ember.computed.or);
export var reads = macroAlias(Ember.computed.reads);
export var setDiff = macroAlias(Ember.computed.setDiff);
export var sort = macroAlias(Ember.computed.sort);
export var sum = macroAlias(Ember.computed.sum);
export var union = macroAlias(Ember.computed.union);
export var uniq = macroAlias(Ember.computed.uniq);
