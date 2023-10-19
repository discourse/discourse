import { htmlSafe } from "@ember/template";
import I18n from "discourse-i18n";

export default function boundI18n(key, options) {
  return htmlSafe(I18n.t(key, options));
}
