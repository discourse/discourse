import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("raw-eq", function (a, b) {
  return a === b;
});
