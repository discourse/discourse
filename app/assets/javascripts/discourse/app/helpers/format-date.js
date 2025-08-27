import { htmlSafe } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

/**
  Display logic for dates. It is unbound in Ember but will use jQuery to
  update the dates on a regular interval.
**/

export default function formatDate(val, params = {}) {
  let leaveAgo,
    format = "medium",
    title = true;

  if (params.leaveAgo) {
    leaveAgo = params.leaveAgo === "true";
  }
  if (params.format) {
    format = params.format;
  }
  if (params.noTitle) {
    title = false;
  }

  if (val) {
    let date = new Date(val);
    return htmlSafe(
      autoUpdatingRelativeAge(date, {
        format,
        title,
        leaveAgo,
        prefix: params.prefix,
      })
    );
  }
}
