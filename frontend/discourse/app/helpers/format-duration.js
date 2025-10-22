import { htmlSafe } from "@ember/template";
import { durationTiny } from "discourse/lib/formatter";

export default function formatDuration(seconds) {
  return htmlSafe(durationTiny(seconds));
}
