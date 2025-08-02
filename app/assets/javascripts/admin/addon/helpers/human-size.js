import { htmlSafe } from "@ember/template";
import I18n from "discourse-i18n";

export default function (size) {
  return htmlSafe(I18n.toHumanSize(size));
}
