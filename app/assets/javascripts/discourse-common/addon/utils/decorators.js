import { on as emberOn } from "@ember/object/evented";
import { computed, observer } from "@ember/object";
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
      if (!this.isDestroying && !this.isDestroyed) {
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

export let on = decoratorAlias(emberOn, "Can not `on` without event names");
export let observes = decoratorAlias(
  observer,
  "Can not `observe` without property names"
);

export let alias = macroAlias(computed.alias);
export let and = macroAlias(computed.and);
export let bool = macroAlias(computed.bool);
export let collect = macroAlias(computed.collect);
export let empty = macroAlias(computed.empty);
export let equal = macroAlias(computed.equal);
export let filter = macroAlias(computed.filter);
export let filterBy = macroAlias(computed.filterBy);
export let gt = macroAlias(computed.gt);
export let gte = macroAlias(computed.gte);
export let lt = macroAlias(computed.lt);
export let lte = macroAlias(computed.lte);
export let map = macroAlias(computed.map);
export let mapBy = macroAlias(computed.mapBy);
export let match = macroAlias(computed.match);
export let max = macroAlias(computed.max);
export let min = macroAlias(computed.min);
export let none = macroAlias(computed.none);
export let not = macroAlias(computed.not);
export let notEmpty = macroAlias(computed.notEmpty);
export let oneWay = macroAlias(computed.oneWay);
export let or = macroAlias(computed.or);
export let reads = macroAlias(computed.reads);
export let setDiff = macroAlias(computed.setDiff);
export let sort = macroAlias(computed.sort);
export let sum = macroAlias(computed.sum);
export let union = macroAlias(computed.union);
export let uniq = macroAlias(computed.uniq);
