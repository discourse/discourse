import { htmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse/lib/helpers";
import { renderIcon } from "discourse/lib/icon-library";

registerRawHelper("check-icon", checkIcon);

export default function checkIcon(value) {
  let icon = value ? "check" : "xmark";
  return htmlSafe(renderIcon("string", icon));
}
