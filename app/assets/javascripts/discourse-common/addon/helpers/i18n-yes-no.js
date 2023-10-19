import { registerRawHelper } from "discourse-common/lib/helpers";
import I18n from "discourse-i18n";

registerRawHelper("i18n-yes-no", i18nYesNo);

export default function i18nYesNo(value, params) {
  return I18n.t(value ? "yes_value" : "no_value", params);
}
