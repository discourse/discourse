import { htmlSafe as emberHtmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("html-safe", htmlSafe);

export default function htmlSafe(string) {
  return emberHtmlSafe(string);
}
