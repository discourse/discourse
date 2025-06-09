import { i18n } from "discourse-i18n";

export default function i18nYesNo(value, params) {
  return i18n(value ? "yes_value" : "no_value", params);
}
