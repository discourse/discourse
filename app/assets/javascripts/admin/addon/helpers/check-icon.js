import { htmlSafe } from "@ember/template";
import { renderIcon } from "discourse/lib/icon-library";

export default function checkIcon(value) {
  let icon = value ? "check" : "xmark";
  return htmlSafe(renderIcon("string", icon));
}
