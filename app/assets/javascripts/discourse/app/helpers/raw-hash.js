import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("raw-hash", function (params) {
  return params;
});
