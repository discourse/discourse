import deprecated from "discourse/lib/deprecated";
import { relativeAge } from "discourse/lib/formatter";

export default function inlineDate(dt) {
  deprecated("inline-date helper is deprecated", {
    id: "discourse.inline-date",
    since: "3.1.0.beta6",
  });

  if (dt.value) {
    dt = dt.value();
  }
  return relativeAge(new Date(dt));
}
