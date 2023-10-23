import { default as emberGetUrl } from "discourse-common/lib/get-url";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("get-url", getUrl);

export default function getUrl(value) {
  return emberGetUrl(value);
}
