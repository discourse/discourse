import { registerRawHelper } from "discourse-common/lib/helpers";
import I18n from "discourse-i18n";

export default function i18n(key, params) {
  return I18n.t(key, params);
}

registerRawHelper("i18n", i18n);
