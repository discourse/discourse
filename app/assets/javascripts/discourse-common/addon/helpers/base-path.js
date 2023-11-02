import getUrl from "discourse-common/lib/get-url";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("base-path", basePath);

export default function basePath() {
  return getUrl("");
}
