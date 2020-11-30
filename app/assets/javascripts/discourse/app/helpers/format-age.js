import { autoUpdatingRelativeAge, durationTiny } from "discourse/lib/formatter";
import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("format-age", function (dt) {
  dt = new Date(dt);
  return htmlSafe(autoUpdatingRelativeAge(dt));
});

registerUnbound("format-duration", function (seconds) {
  return htmlSafe(durationTiny(seconds));
});
