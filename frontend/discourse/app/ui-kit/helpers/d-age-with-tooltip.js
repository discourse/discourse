import { trustHTML } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default function dAgeWithTooltip(dt, params = {}) {
  return trustHTML(
    autoUpdatingRelativeAge(new Date(dt), {
      ...params,
      title: params.title ?? true,
    })
  );
}
