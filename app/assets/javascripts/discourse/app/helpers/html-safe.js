import { htmlSafe as emberHtmlSafe } from "@ember/template";

export default function htmlSafe(string) {
  return emberHtmlSafe(string);
}
