import handleDescriptor from "discourse-common/utils/handle-descriptor";
import isDescriptor from "discourse-common/utils/is-descriptor";
import extractValue from "discourse-common/utils/extract-value";
import decoratorAlias from "discourse-common/utils/decorator-alias";
import macroAlias from "discourse-common/utils/macro-alias";
import { schedule, next } from "@ember/runloop";
import { bind as emberBind } from "@ember/runloop";

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
    next(() => {
      schedule("afterRender", () => {
        if (this.element && !this.isDestroying && !this.isDestroyed) {
          return originalFunction.apply(this, arguments);
        }
      });
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
    initializer: function () {
      let value = extractValue(desc);
      return value.readOnly();
    },
  };
}

/* eslint-disable */
export let on = decoratorAlias(Ember.on, "Can not `on` without event names");
export let observes = decoratorAlias(
  Ember.observer,
  "Can not `observe` without property names"
);

export let alias = macroAlias(Ember.computed.alias);
export let and = macroAlias(Ember.computed.and);
export let bool = macroAlias(Ember.computed.bool);
export let collect = macroAlias(Ember.computed.collect);
export let empty = macroAlias(Ember.computed.empty);
export let equal = macroAlias(Ember.computed.equal);
export let filter = macroAlias(Ember.computed.filter);
export let filterBy = macroAlias(Ember.computed.filterBy);
export let gt = macroAlias(Ember.computed.gt);
export let gte = macroAlias(Ember.computed.gte);
export let lt = macroAlias(Ember.computed.lt);
export let lte = macroAlias(Ember.computed.lte);
export let map = macroAlias(Ember.computed.map);
export let mapBy = macroAlias(Ember.computed.mapBy);
export let match = macroAlias(Ember.computed.match);
export let max = macroAlias(Ember.computed.max);
export let min = macroAlias(Ember.computed.min);
export let none = macroAlias(Ember.computed.none);
export let not = macroAlias(Ember.computed.not);
export let notEmpty = macroAlias(Ember.computed.notEmpty);
export let oneWay = macroAlias(Ember.computed.oneWay);
export let or = macroAlias(Ember.computed.or);
export let reads = macroAlias(Ember.computed.reads);
export let setDiff = macroAlias(Ember.computed.setDiff);
export let sort = macroAlias(Ember.computed.sort);
export let sum = macroAlias(Ember.computed.sum);
export let union = macroAlias(Ember.computed.union);
export let uniq = macroAlias(Ember.computed.uniq);
