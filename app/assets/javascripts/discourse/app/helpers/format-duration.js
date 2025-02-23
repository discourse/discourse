import { htmlSafe } from "@ember/template";
import { durationTiny } from "discourse/lib/formatter";
import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("format-duration", formatDuration);
export default function formatDuration(seconds) {
  return htmlSafe(durationTiny(seconds));
}
