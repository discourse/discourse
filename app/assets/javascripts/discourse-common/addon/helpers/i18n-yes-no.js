import I18n from "I18n";
import { registerRawHelper } from "discourse-common/lib/helpers";

export default function i18n(key, params) {
  return I18n.t(key, params);
}

registerRawHelper("i18n", i18n);
