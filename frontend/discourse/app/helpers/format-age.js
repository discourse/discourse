import { trustHTML } from "@ember/template";
import deprecated from "discourse/lib/deprecated";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default function formatAge(dt) {
  deprecated(`formatAge helper is deprecated. Use ageWithTooltip instead.`, {
    since: "3.5.0.beta5-dev",
    id: "discourse.format-age",
  });

  return trustHTML(autoUpdatingRelativeAge(new Date(dt)));
}
