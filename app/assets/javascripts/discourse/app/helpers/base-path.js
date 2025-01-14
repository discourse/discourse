import getUrl from "discourse/lib/get-url";
import { registerRawHelper } from "discourse/lib/helpers";

registerRawHelper("base-path", basePath);

export default function basePath() {
  return getUrl("");
}
