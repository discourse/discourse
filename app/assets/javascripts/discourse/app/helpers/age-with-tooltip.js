import { htmlSafe } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default function ageWithTooltip(dt, params = {}) {
  return htmlSafe(
    autoUpdatingRelativeAge(new Date(dt), {
      customTitle: params.customTitle,
      title: true,
      addAgo: params.addAgo || false,
      ...(params.defaultFormat && { defaultFormat: params.defaultFormat }),
    })
  );
}
