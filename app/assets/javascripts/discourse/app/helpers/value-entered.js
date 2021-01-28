import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("value-entered", function (value) {
  if (value === undefined || value === null) {
    return "";
  } else if (value.length > 0) {
    return "value-entered";
  } else {
    return "";
  }
});
