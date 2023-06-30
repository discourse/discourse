import { relativeAge } from "discourse/lib/formatter";

export default function inlineDate(dt) {
  // TODO: Remove this in 1.13 or greater
  if (dt.value) {
    dt = dt.value();
  }
  return relativeAge(new Date(dt));
}
