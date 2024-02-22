import { htmlSafe } from "@ember/template";
import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default function boundDate(dt) {
  return htmlSafe(
    autoUpdatingRelativeAge(new Date(dt), {
      format: "medium",
      title: true,
    })
  );
}
