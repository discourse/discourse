import { get } from "@ember/object";

export default function withEventValue(mutFn, path = "target.value") {
  return function (event) {
    return mutFn(get(event, path));
  };
}
