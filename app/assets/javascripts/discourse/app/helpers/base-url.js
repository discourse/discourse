import deprecated from "discourse/lib/deprecated";
import getUrl from "discourse/lib/get-url";
import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("base-url", baseUrl);

export default function baseUrl() {
  deprecated("Use `{{base-path}}` instead of `{{base-url}}`", {
    id: "discourse.base-url",
  });
  return getUrl("");
}
