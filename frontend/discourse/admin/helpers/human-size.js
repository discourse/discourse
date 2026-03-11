import { trustHTML } from "@ember/template";
import I18n from "discourse-i18n";

export default function (size) {
  return trustHTML(I18n.toHumanSize(size));
}
