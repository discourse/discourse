import { helper } from "@ember/component/helper";
import * as EmberDebug from "@ember/debug";

/**
 * Calls @ember/debug `deprecate` for each provided set of `deprecate` params.
 */
const deprecationsHelper = helper(([deprecationsJson]) => {
  for (const deprecation of JSON.parse(deprecationsJson)) {
    EmberDebug.deprecate(...deprecation);
  }
});

export default deprecationsHelper;
