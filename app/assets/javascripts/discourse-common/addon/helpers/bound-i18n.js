import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

export default function boundI18n(key, options) {
  return htmlSafe(i18n(key, options));
}
