import { registerRawHelper } from "discourse-common/lib/helpers";
import { i18n } from "discourse-i18n";

registerRawHelper("i18n", i18n);

export default function i18n(key, params) {
  return i18n(key, params);
}
