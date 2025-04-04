import { htmlSafe } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default function formatAge(dt) {
  dt = new Date(dt);
  return htmlSafe(autoUpdatingRelativeAge(dt));
}
