import { htmlSafe } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("format-age", formatAge);
export default function formatAge(dt) {
  dt = new Date(dt);
  return htmlSafe(autoUpdatingRelativeAge(dt));
}
