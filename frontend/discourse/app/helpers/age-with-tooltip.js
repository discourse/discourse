import { trustHTML } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default function ageWithTooltip(dt, params = {}) {
  return trustHTML(
    autoUpdatingRelativeAge(new Date(dt), {
      ...params,
      title: params.title ?? true,
    })
  );
}
