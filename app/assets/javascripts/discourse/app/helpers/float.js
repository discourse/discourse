import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("float", function(n) {
  return parseFloat(n).toFixed(1);
});
