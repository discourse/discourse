import { autoUpdatingRelativeAge } from "discourse/lib/formatter";

export default function boundDate(dt) {
  return autoUpdatingRelativeAge(new Date(dt), {
    format: "medium",
    title: true,
  });
}
