import I18n from "I18n";
import { htmlSafe } from "@ember/template";

export default function boundI18n(key, options) {
  return htmlSafe(I18n.t(key, options));
}
