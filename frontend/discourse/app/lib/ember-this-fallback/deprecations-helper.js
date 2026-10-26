import { helper } from "@ember/component/helper";
import * as EmberDebug from "@ember/debug";

export default helper(([deprecationsJson]) => {
  for (const deprecation of JSON.parse(deprecationsJson)) {
    EmberDebug.deprecate(...deprecation);
  }
});
