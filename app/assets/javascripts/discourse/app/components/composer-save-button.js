import Button from "discourse/components/d-button";
import I18n from "I18n";
import { macFriendlyShortcutLabel } from "discourse/lib/utilities";

export default Button.extend({
  classNameBindings: [":btn-primary", ":create", "disableSubmit:disabled"],
  translatedTitle: macFriendlyShortcutLabel(I18n.t("composer.title"), {
    replaceCtrl: true,
  }),
});
