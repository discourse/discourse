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

export const on = decoratorAlias(emberOn, "Can not `on` without event names");
export const observes = decoratorAlias(
  observer,
  "Can not `observe` without property names"
);

export const alias = macroAlias(computed.alias);
export const and = macroAlias(computed.and);
export const bool = macroAlias(computed.bool);
export const collect = macroAlias(computed.collect);
export const empty = macroAlias(computed.empty);
export const equal = macroAlias(computed.equal);
export const filter = macroAlias(computed.filter);
export const filterBy = macroAlias(computed.filterBy);
export const gt = macroAlias(computed.gt);
export const gte = macroAlias(computed.gte);
export const lt = macroAlias(computed.lt);
export const lte = macroAlias(computed.lte);
export const map = macroAlias(computed.map);
export const mapBy = macroAlias(computed.mapBy);
export const match = macroAlias(computed.match);
export const max = macroAlias(computed.max);
export const min = macroAlias(computed.min);
export const none = macroAlias(computed.none);
export const not = macroAlias(computed.not);
export const notEmpty = macroAlias(computed.notEmpty);
export const oneWay = macroAlias(computed.oneWay);
export const or = macroAlias(computed.or);
export const reads = macroAlias(computed.reads);
export const setDiff = macroAlias(computed.setDiff);
export const sort = macroAlias(computed.sort);
export const sum = macroAlias(computed.sum);
export const union = macroAlias(computed.union);
export const uniq = macroAlias(computed.uniq);
