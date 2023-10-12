import { htmlSafe } from "@ember/template";
import I18n from "I18n";

export default function boundI18n(key, options) {
  return htmlSafe(I18n.t(key, options));
}
