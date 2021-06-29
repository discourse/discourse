import { computed } from "@ember/object";
import { getOwner } from "@ember/application";
import { dasherize } from "@ember/string";

export default function (name) {
  return computed(function (defaultName) {
    return getOwner(this).lookup(`service:${name || dasherize(defaultName)}`);
  });
}
