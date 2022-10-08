import { later } from "@ember/runloop";
import { isTesting } from "discourse-common/config/environment";

export default function () {
  if (isTesting() && typeof [...arguments].at(-1) === "number") {
    // Replace the `wait` argument with 10ms
    let args = [].slice.call(arguments, 0, -1);
    args.push(10);

    return later.apply(undefined, args);
  } else {
    return later(...arguments);
  }
}
