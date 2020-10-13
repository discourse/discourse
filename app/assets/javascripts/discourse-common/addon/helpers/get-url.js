import { registerUnbound } from "discourse-common/lib/helpers";
import getUrl from "discourse-common/lib/get-url";
import deprecated from "discourse-common/lib/deprecated";

registerUnbound("get-url", (value) => getUrl(value));
registerUnbound("base-url", () => {
  deprecated("Use `{{base-path}}` instead of `{{base-url}}`");
  return getUrl("");
});
registerUnbound("base-path", () => getUrl(""));
