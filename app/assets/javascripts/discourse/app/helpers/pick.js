import { get } from "@ember/object";

export default function pick(mutFn) {
  return function (event) {
    return mutFn(get(event, "target.value"));
  };
}
