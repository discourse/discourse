import { computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import { dasherize } from "@ember/string";

export default function (target, name, descriptor) {
  name ??= target;

  const decorator = computed(function (defaultName) {
    return getOwner(this).lookup(`service:${name || dasherize(defaultName)}`);
  });

  if (descriptor) {
    return decorator(target, name, descriptor);
  } else {
    return decorator;
  }
}
