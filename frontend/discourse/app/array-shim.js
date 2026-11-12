import { consumeTag, tagFor } from "@glimmer/validator";
import deprecated from "discourse/lib/deprecated";

/**
 * Defines the deprecated Ember `firstObject` and `lastObject` getters on native arrays.
 **/

function defineDeprecatedGetter(name, replacement, read) {
  // eslint-disable-next-line no-extend-native
  Object.defineProperty(Array.prototype, name, {
    configurable: true,
    enumerable: false,
    get() {
      if (this !== Array.prototype) {
        deprecated(
          `The array.${name} getter is a deprecated Ember native array extension. Use ${replacement} instead.`,
          {
            id: `discourse.native-array-extensions.${name}`,
            since: "2026.11.0-latest",
          }
        );
        consumeTag(tagFor(this, "[]"));
      }

      return read(this);
    },
  });
}

defineDeprecatedGetter(
  "firstObject",
  "array[0] or array.at(0)",
  (array) => array[0]
);
defineDeprecatedGetter("lastObject", "array.at(-1)", (array) => array.at(-1));
