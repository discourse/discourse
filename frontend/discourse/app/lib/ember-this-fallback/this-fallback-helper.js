import { helper } from "@ember/component/helper";
import * as EmberDebug from "@ember/debug";
import { get } from "@ember/object";

export default helper(([context, path, deprecationJson]) => {
  if (deprecationJson) {
    EmberDebug.deprecate(...JSON.parse(deprecationJson));
  }
  return get(context, path);
});
