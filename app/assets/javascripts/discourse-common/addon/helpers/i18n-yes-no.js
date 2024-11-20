import { registerRawHelper } from "discourse-common/lib/helpers";
import { i18n } from "discourse-i18n";

registerRawHelper("i18n-yes-no", i18nYesNo);

export default function i18nYesNo(value, params) {
  return i18n(value ? "yes_value" : "no_value", params);
}
