import { htmlSafe } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default function ageWithTooltip(dt, params = {}) {
  params.title ??= true;
  return htmlSafe(autoUpdatingRelativeAge(new Date(dt), params));
}
