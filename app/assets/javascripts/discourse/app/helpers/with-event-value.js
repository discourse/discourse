import { get } from "@ember/object";

export default function withEventValue(mutFn) {
  return function (event) {
    return mutFn(get(event, "target.value"));
  };
}
