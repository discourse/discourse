import { htmlSafe } from "@ember/template";
import { longDate } from "discourse/lib/formatter";
import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("raw-date", rawDate);

export default function rawDate(dt) {
  return htmlSafe(longDate(new Date(dt)));
}
