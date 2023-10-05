import { registerRawHelper } from "discourse-common/lib/helpers";
import { longDate } from "discourse/lib/formatter";
import { htmlSafe } from "@ember/template";

registerRawHelper("raw-date", rawDate);

export default function rawDate(dt) {
  return htmlSafe(longDate(new Date(dt)));
}
