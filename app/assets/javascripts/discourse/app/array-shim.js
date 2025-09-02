import { NativeArray } from "@ember/array";
import deprecated, { withSilencedDeprecations } from "discourse/lib/deprecated";
import escapeRegExp from "discourse/lib/escape-regexp";

/**
 * Provides backward compatibility for Ember native array extensions that were deprecated and removed in Ember 6.0.
 *
 * This file shims the array extension methods previously added by Ember to the native Array prototype.
 *
 * It adds deprecation warnings for each method to help identify and track their usage in the codebase.
 *
 * This allows existing code to continue working while providing guidance for migration to native array methods or
 * TrackedArray alternatives.
 **/

const DEPRECATION_ID_PREFIX = "discourse.native-array-extensions";
const SILENCED_ARRAY_DEPRECATIONS = new RegExp(
  `^${escapeRegExp(DEPRECATION_ID_PREFIX)}\..+$`
);
const DEPRECATION_SINCE = "3.6.0.beta1-dev";

/**
 * Display a consistent deprecation warning for array extension usage.
 *
 * @param {string} name
 * @param {"method"|"getter"|"setter"} kind
 */
function warn(name, kind = "method") {
  const qualifiedName =
    kind === "method" ? `array.${name}` : `array["${name}"] ${kind}`;

  deprecated(
    `The ${qualifiedName} is a deprecated Ember native array extension. Use native array methods or a TrackedArray instead.`,
    {
      id: `${DEPRECATION_ID_PREFIX}.${name}`,
      since: DEPRECATION_SINCE,
    }
  );
}

/**
 * Checks if a method is a deprecated Ember native array extension
 *
 * @param {string} methodName - The name of the method to check
 * @returns {boolean} True if the method is deprecated, false otherwise
 */
function isDeprecatedMethod(methodName) {
  return (
    NativeArray._without.indexOf(methodName) === -1 &&
    Array.prototype[methodName] &&
    methodName !== "[]" // [] is a special case - a getter/setter property added by Ember's NativeArray
  );
}

/**
 * Wraps an Array.prototype method with a deprecation warning
 *
 * @param {string} methodName - The name of the method to deprecate
 */
function deprecateArrayMethod(methodName) {
  const original = Array.prototype[methodName];

  // eslint-disable-next-line no-extend-native
  Array.prototype[methodName] = function (...args) {
    warn(methodName);

    return withSilencedDeprecations(SILENCED_ARRAY_DEPRECATIONS, () =>
      original.apply(this, args)
    );
  };
}

/**
 * Wraps the special case '[]' property descriptor with deprecation warnings
 * for both getter and setter
 */
function wrapSquareBracketDescriptor() {
  const propertyName = "[]";
  const squareBracketDescriptor = Object.getOwnPropertyDescriptor(
    Array.prototype,
    propertyName
  );
  if (!squareBracketDescriptor) {
    return;
  }

  // eslint-disable-next-line no-extend-native
  Object.defineProperty(Array.prototype, propertyName, {
    get() {
      warn(propertyName, "getter");

      return withSilencedDeprecations(SILENCED_ARRAY_DEPRECATIONS, () =>
        squareBracketDescriptor.get.bind(this)()
      );
    },
    set(value) {
      warn(propertyName, "setter");

      withSilencedDeprecations(SILENCED_ARRAY_DEPRECATIONS, () => {
        squareBracketDescriptor.set.bind(this)(value);
      });
    },
  });
}

// Apply the shim to the native Array prototype to mantain compatibility with existing code.
NativeArray.apply(Array.prototype, true);

// Wrap all applicable native array extension methods with deprecations
Array.from(NativeArray.keys())
  .filter(isDeprecatedMethod)
  .forEach((methodName) => deprecateArrayMethod(methodName));

// Apply the special-case wrapper
wrapSquareBracketDescriptor();
