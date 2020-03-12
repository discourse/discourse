import { relativeAge } from "discourse/lib/formatter";
import { registerHelper } from "discourse-common/lib/helpers";

registerHelper("inline-date", function([dt]) {
  // TODO: Remove this in 1.13 or greater
  if (dt.value) {
    dt = dt.value();
  }
  return relativeAge(new Date(dt));
});
