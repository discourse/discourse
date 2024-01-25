import { get } from "@ember/object";

export default function pick(mutFn, path = "target.value") {
  return function (event) {
    return mutFn(get(event, path));
  };
}
