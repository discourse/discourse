import { makeArray } from "discourse/lib/helpers";

export function integerIdsFromValue(value) {
  return makeArray(value)
    .map((id) => parseInt(id, 10))
    .filter((id) => !isNaN(id));
}

export function sameIds(a, b) {
  return a.length === b.length && a.every((id, index) => id === b[index]);
}
