import { NativeArray } from "@ember/array";
import deprecated, { withSilencedDeprecations } from "discourse/lib/deprecated";

/**
 * Provides backward compatibility for Ember native array extensions that were deprecated and removed in Ember 6.0.
 *
 * This file shims the array extension methods previously added by Ember to the native Array prototype.
 *
 * It adds deprecation warnings for each method to help identify and track their usage in the codebase.
 *
 * This allows existing code to continue working while providing guidance for migration to native array methods,
 * EmberArray, or TrackedArray alternatives.
 **/

const ARRAY_PROTO = Array.prototype;
const DEPRECATION_ID_PREFIX = "discourse.ember.native-array-extensions";
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
    `The ${qualifiedName} is a deprecated Ember native array extension. Use native array methods, an EmberArray, or a TrackedArray instead.`,
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
    ARRAY_PROTO[methodName] &&
    methodName !== "[]" // [] is a special case - a getter/setter property added by Ember's NativeArray
  );
}

/**
 * Wraps an Array.prototype method with a deprecation warning
 *
 * @param {string} methodName - The name of the method to deprecate
 */
function deprecateArrayMethod(methodName) {
  const original = ARRAY_PROTO[methodName];

  ARRAY_PROTO[methodName] = function (...args) {
    warn(methodName);
    return original.apply(this, args);
  };
}

/**
 * Wraps the special case '[]' property descriptor with deprecation warnings
 * for both getter and setter
 */
function wrapSquareBracketDescriptor() {
  const squareBracketDescriptor = Object.getOwnPropertyDescriptor(
    ARRAY_PROTO,
    "[]"
  );
  if (!squareBracketDescriptor) {
    return;
  }

  Object.defineProperty(ARRAY_PROTO, "[]", {
    get() {
      warn("[]", "getter");
      return squareBracketDescriptor.get.bind(this)();
    },
    set(value) {
      warn("[]", "setter");
      withSilencedDeprecations(`${DEPRECATION_ID_PREFIX}.replace`, () => {
        squareBracketDescriptor.set.bind(this)(value);
      });
    },
  });
}

// Apply the shim to the native Array prototype to mantain compatibility with existing code.
NativeArray.apply(ARRAY_PROTO, true);

// Wrap all applicable native array extension methods with deprecations
Array.from(NativeArray.keys())
  .filter(isDeprecatedMethod)
  .forEach((methodName) => deprecateArrayMethod(methodName));

// Apply the special-case wrapper
wrapSquareBracketDescriptor();
