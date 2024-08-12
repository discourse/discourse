import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("raw-hash", function (params) {
  return params;
});
