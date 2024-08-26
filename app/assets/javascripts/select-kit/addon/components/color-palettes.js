import { classNames } from "@ember-decorators/component";
import I18n from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@classNames("color-palettes")
@selectKitOptions({
  translatedNone: I18n.t("admin.customize.theme.default_light_scheme"),
})
@pluginApiIdentifiers(["color-palettes"])
export default class ColorPalettes extends ComboBoxComponent {
  modifyComponentForRow() {
    return "color-palettes/color-palettes-row";
  }
}
