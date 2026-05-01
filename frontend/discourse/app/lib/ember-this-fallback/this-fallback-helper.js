import { helper } from "@ember/component/helper";
import { deprecate } from "@ember/debug";
import { get } from "@ember/object";

export default helper(([context, path, deprecationJson]) => {
  if (deprecationJson) {
    deprecate(...JSON.parse(deprecationJson));
  }
  return get(context, path);
});
