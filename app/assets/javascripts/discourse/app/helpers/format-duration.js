import { htmlSafe } from "@ember/template";
import { durationTiny } from "discourse/lib/formatter";
import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("format-duration", function (seconds) {
  return formatDuration(seconds);
});

export default function formatDuration(seconds) {
  return htmlSafe(durationTiny(seconds));
}
