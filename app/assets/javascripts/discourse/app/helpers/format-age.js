import { autoUpdatingRelativeAge, durationTiny } from "discourse/lib/formatter";
import { registerUnbound } from "discourse-common/lib/helpers";
import { htmlSafe } from "@ember/template";

registerUnbound("format-age", function(dt) {
  dt = new Date(dt);
  return htmlSafe(autoUpdatingRelativeAge(dt));
});

registerUnbound("format-duration", function(seconds) {
  return htmlSafe(durationTiny(seconds));
});
