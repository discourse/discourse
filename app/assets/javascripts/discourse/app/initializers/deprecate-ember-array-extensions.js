import { NativeArray } from "@ember/array";
import deprecated from "discourse/lib/deprecated";

export default {
  before: "discourse-bootstrap",

  // Ember native array extensions are deprecated and were dropped in Ember 6.0. We need to add deprecation warnings to
  // each method to collect data about their usage and make it easier to track them in the source code.
  initialize() {
    Array.from(NativeArray.keys())
      .filter(
        (k) =>
          NativeArray._without.indexOf(k) === -1 &&
          Array.prototype[k] &&
          k !== "[]" // TODO (ember-native-array-extensions) remove this exception
      )
      .forEach((k) => {
        const deprecatedMethod = Array.prototype[k];
        // eslint-disable-next-line no-extend-native
        Array.prototype[k] = function () {
          deprecated(
            "[]." +
              k +
              " is an Ember native array extension and is deprecated. Use the native array methods or an Ember array instead.",
            {
              id: `discourse.ember.native-array-extensions`,
              since: "3.6.0.beta1-dev",
            }
          );
          return deprecatedMethod.apply(this, arguments);
        };
      });
  },
};
