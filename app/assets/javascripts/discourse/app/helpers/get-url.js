import { default as emberGetUrl } from "discourse/lib/get-url";
import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("get-url", getUrl);

export default function getUrl(value) {
  return emberGetUrl(value);
}
