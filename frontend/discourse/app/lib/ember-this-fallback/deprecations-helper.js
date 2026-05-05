import { helper } from "@ember/component/helper";
import { deprecate } from "@ember/debug";

export default helper(([deprecationsJson]) => {
  for (const deprecation of JSON.parse(deprecationsJson)) {
    deprecate(...deprecation);
  }
});
