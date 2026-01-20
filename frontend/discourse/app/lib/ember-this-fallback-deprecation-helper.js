import { helper } from "@ember/component/helper";
import { deprecate } from "@ember/debug";

/**
 * Calls @ember/debug `deprecate` for each provided set of `deprecate` params.
 */
const deprecationsHelper = helper(([deprecationsJson]) => {
  for (const deprecation of JSON.parse(deprecationsJson)) {
    deprecate(...deprecation);
  }
});

export default deprecationsHelper;
