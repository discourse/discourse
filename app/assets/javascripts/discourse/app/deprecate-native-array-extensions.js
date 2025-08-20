import { NativeArray } from "@ember/array";
import deprecated, { withSilencedDeprecations } from "discourse/lib/deprecated";

// Ember native array extensions are deprecated and were dropped in Ember 6.0. We need to add deprecation warnings to
// each method to collect data about their usage and make it easier to track them in the source code.
Array.from(NativeArray.keys())
  .filter(
    (k) =>
      NativeArray._without.indexOf(k) === -1 && Array.prototype[k] && k !== "[]" // [] is a special case - a getter/setter property added by Ember's NativeArray
  )
  .forEach((k) => {
    const deprecatedMethod = Array.prototype[k];
    // eslint-disable-next-line no-extend-native
    Array.prototype[k] = function () {
      deprecated(
        "array." +
          k +
          " is an Ember native array extension and is deprecated. Use the native array methods or an Ember array instead.",
        {
          id: `discourse.ember.native-array-extensions.${k}`,
          since: "3.6.0.beta1-dev",
        }
      );
      return deprecatedMethod.apply(this, arguments);
    };
  });

// Handle the special case of `[]`
const squareBracketDescriptor = Object.getOwnPropertyDescriptor(
  Array.prototype,
  "[]"
);

// eslint-disable-next-line no-extend-native
Object.defineProperty(Array.prototype, "[]", {
  get() {
    deprecated(
      'array["[]"] is an Ember native array extension and is deprecated. Use the native array methods or an Ember array instead.',
      {
        id: "discourse.ember.native-array-extensions.[]",
        since: "3.6.0.beta1-dev",
      }
    );

    return squareBracketDescriptor.get.bind(this)();
  },
  set(value) {
    deprecated(
      'array["[]"] is an Ember native array extension and is deprecated. Use the native array methods or an Ember array instead.',
      {
        id: "discourse.ember.native-array-extensions.[]",
        since: "3.6.0.beta1-dev",
      }
    );

    withSilencedDeprecations(
      "discourse.ember.native-array-extensions.replace",
      () => {
        squareBracketDescriptor.set.bind(this)(value);
      }
    );
  },
});
