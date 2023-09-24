import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("abs", function (n) {
  return Math.abs(n);
});
