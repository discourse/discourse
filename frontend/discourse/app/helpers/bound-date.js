import { htmlSafe } from "@ember/template";
import deprecated from "discourse/lib/deprecated";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default function boundDate(dt) {
  deprecated(`boundDate helper is deprecated. Use ageWithTooltip instead.`, {
    since: "3.5.0.beta5-dev",
    id: "discourse.bound-date",
  });

  return htmlSafe(
    autoUpdatingRelativeAge(new Date(dt), {
      format: "medium",
      title: true,
    })
  );
}
