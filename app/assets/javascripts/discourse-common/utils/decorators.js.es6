import handleDescriptor from "ember-addons/utils/handle-descriptor";
import isDescriptor from "ember-addons/utils/is-descriptor";
import extractValue from "ember-addons/utils/extract-value";
import { schedule, next } from "@ember/runloop";

export default function discourseComputedDecorator(...params) {
  // determine if user called as @discourseComputed('blah', 'blah') or @discourseComputed
  if (isDescriptor(params[params.length - 1])) {
    return handleDescriptor(...arguments);
  } else {
    return function(/* target, key, desc */) {
      return handleDescriptor(...arguments, params);
    };
  }
}

export function afterRender(target, name, descriptor) {
  const originalFunction = descriptor.value;
  descriptor.value = function() {
    next(() => {
      schedule("afterRender", () => {
        if (this.element && !this.isDestroying && !this.isDestroyed) {
          return originalFunction.apply(this, arguments);
        }
      });
    });
  };
}

export function readOnly(target, name, desc) {
  return {
    writable: false,
    enumerable: desc.enumerable,
    configurable: desc.configurable,
    initializer: function() {
      var value = extractValue(desc);
      return value.readOnly();
    }
  };
}

import decoratorAlias from "ember-addons/decorator-alias";

export var on = decoratorAlias(Ember.on, "Can not `on` without event names");
export var observes = decoratorAlias(
  Ember.observer,
  "Can not `observe` without property names"
);

import macroAlias from "ember-addons/macro-alias";

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
