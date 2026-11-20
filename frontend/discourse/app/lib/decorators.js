import { observer } from "@ember/object";
import CoreObject from "@ember/object/core";
import { on as emberOn } from "@ember/object/evented";
import { bind as emberBind, schedule } from "@ember/runloop";
import discourseDebounce from "discourse/lib/debounce";
import decoratorAlias from "discourse/lib/decorator-alias";
import extractValue from "discourse/lib/extract-value";
import handleDescriptor from "discourse/lib/handle-descriptor";
import isDescriptor from "discourse/lib/is-descriptor";

/**
 * A decorator that creates computed properties with dependent keys.
 * This decorator allows you to define computed properties that automatically
 * update when their dependent properties change.
 *
 * @deprecated Use `@tracked` properties with native getters or the standard `@computed`
 * decorator from `@ember/object` instead.
 *
 * @param {...(string|PropertyDescriptor)} params - Either dependent property keys as strings,
 * or a property descriptor when used without arguments
 * @returns {PropertyDescriptor|Function} A property descriptor or decorator function
 *
 * @example
 * // Usage with dependent keys
 * class MyComponent {
 *   @discourseComputed('firstName', 'lastName')
 *   fullName(firstName, lastName) {
 *     return `${firstName} ${lastName}`;
 *   }
 * }
 *
 * @example
 * // Usage without arguments
 * class MyComponent {
 *   @discourseComputed
 *   currentTime() {
 *     return new Date();
 *   }
 * }
 *
 * @example
 * // Recommended alternative with @computed from @ember/object
 * import { computed } from '@ember/object';
 *
 * class MyComponent {
 *   @computed('firstName', 'lastName')
 *   get fullName() {
 *     return `${this.firstName} ${this.lastName}`;
 *   }
 * }
 *
 * @example
 * // Recommended alternative with @tracked properties
 * import { tracked } from '@glimmer/tracking';
 *
 * class MyComponent {
 *   @tracked firstName;
 *   @tracked lastName;
 *
 *   get fullName() {
 *     return `${this.firstName} ${this.lastName}`;
 *   }
 * }
 */
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
      if (!this.isDestroying) {
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
      const attributes = { ...descriptor, value: bound };

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

export function debounce(delay, immediate = false) {
  return function (target, name, descriptor) {
    return {
      enumerable: descriptor.enumerable,
      configurable: descriptor.configurable,
      get: function () {
        const originalFunction = descriptor.value;
        const debounced = (...args) => {
          return discourseDebounce(
            this,
            originalFunction,
            ...args,
            delay,
            immediate
          );
        };

        // Memoize on instance for future access
        Object.defineProperty(this, name, {
          value: debounced,
          enumerable: descriptor.enumerable,
          configurable: descriptor.configurable,
        });

        return debounced;
      },
    };
  };
}

export function on(...onParams) {
  return function (target) {
    if (target instanceof CoreObject) {
      throw new Error(
        "`on` from 'discourse/lib/decorators' only works with `.extend()`. Import it from '@ember-decorators/object' for native classes."
      );
    }
    return decoratorAlias(
      emberOn,
      "Can not `on` without event names"
    )(...onParams)(...arguments);
  };
}

export function observes(...observeParams) {
  return function (target) {
    if (target instanceof CoreObject) {
      throw new Error(
        "`observes` from 'discourse/lib/decorators' only works with `.extend()`. Import it from '@ember-decorators/object' for native classes."
      );
    }
    return decoratorAlias(
      observer,
      "Can not `observe` without property names"
    )(...observeParams)(...arguments);
  };
}
