import { isArray } from "@ember/array";
import { get } from "@ember/object";

export default function truthConvert(result) {
  const truthy = result && get(result, "isTruthy");
  if (typeof truthy === "boolean") {
    return truthy;
  }

  if (isArray(result)) {
    return get(result, "length") !== 0;
  } else {
    return !!result;
  }
}
