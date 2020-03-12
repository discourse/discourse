import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("i18n", (key, params) => I18n.t(key, params));
registerUnbound("i18n-yes-no", (value, params) =>
  I18n.t(value ? "yes_value" : "no_value", params)
);
