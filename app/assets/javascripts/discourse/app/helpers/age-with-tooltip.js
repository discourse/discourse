import { htmlSafe } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default function ageWithTooltip(dt, params = {}) {
  return htmlSafe(
    autoUpdatingRelativeAge(new Date(dt), {
      ...params,
      title: params.title ?? true,
    })
  );
}
