import { NativeArray } from "@ember/array";
import deprecated, { withSilencedDeprecations } from "discourse/lib/deprecated";

/**
 * Ember native array extensions are deprecated and were dropped in Ember 6.0. We need to add deprecation warnings to
 * each method to collect data about their usage and make it easier to track them in the source code.
 **/

const DEPRECATION_ID_PREFIX = "discourse.ember.native-array-extensions";
const DEPRECATION_SINCE = "3.6.0.beta1-dev";
const ARRAY_PROTO = Array.prototype;

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

// Wrap all applicable native array extension methods with deprecations
Array.from(NativeArray.keys())
  .filter(isDeprecatedMethod)
  .forEach((methodName) => deprecateArrayMethod(methodName));

// Apply the special-case wrapper
wrapSquareBracketDescriptor();
