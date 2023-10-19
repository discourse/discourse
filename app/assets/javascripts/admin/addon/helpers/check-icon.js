import { htmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse-common/lib/helpers";
import { renderIcon } from "discourse-common/lib/icon-library";

registerRawHelper("check-icon", checkIcon);

export default function checkIcon(value) {
  let icon = value ? "check" : "times";
  return htmlSafe(renderIcon("string", icon));
}
