import { registerHelper } from "discourse-common/lib/helpers";
import { relativeAge } from "discourse/lib/formatter";

registerHelper("inline-date", function ([dt]) {
  return relativeAge(new Date(dt));
});
