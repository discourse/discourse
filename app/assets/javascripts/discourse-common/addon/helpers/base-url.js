import deprecated from "discourse-common/lib/deprecated";
import getUrl from "discourse-common/lib/get-url";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("base-url", baseUrl);

export default function baseUrl() {
  deprecated("Use `{{base-path}}` instead of `{{base-url}}`", {
    id: "discourse.base-url",
  });
  return getUrl("");
}
