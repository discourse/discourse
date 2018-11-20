import Ember from "ember";

const inspect = Ember.inspect;
const isArray = Ember.isArray;

export default function(str, formats) {
  let cachedFormats = formats;

  if (!isArray(cachedFormats) || arguments.length > 2) {
    cachedFormats = new Array(arguments.length - 1);

    for (let i = 1, l = arguments.length; i < l; i++) {
      cachedFormats[i - 1] = arguments[i];
    }
  }

  // first, replace any ORDERED replacements.
  let idx = 0; // the current index for non-numerical replacements
  return str.replace(/%@([0-9]+)?/g, function(s, argIndex) {
    argIndex = argIndex ? parseInt(argIndex, 10) - 1 : idx++;
    s = cachedFormats[argIndex];
    return s === null ? "(null)" : s === undefined ? "" : inspect(s);
  });
}
