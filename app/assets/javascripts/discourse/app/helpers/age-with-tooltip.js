import { htmlSafe } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";
import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("age-with-tooltip", ageWithTooltip);

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
