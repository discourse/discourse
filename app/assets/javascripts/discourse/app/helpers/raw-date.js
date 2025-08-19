import { htmlSafe } from "@ember/template";
import { longDate } from "discourse/lib/formatter";

export default function rawDate(dt) {
  return htmlSafe(longDate(new Date(dt)));
}
