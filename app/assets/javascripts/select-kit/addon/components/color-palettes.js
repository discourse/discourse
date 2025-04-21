import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@classNames("color-palettes")
@selectKitOptions({
  translatedNone: i18n("admin.customize.theme.default_light_scheme"),
})
@pluginApiIdentifiers(["color-palettes"])
export default class ColorPalettes extends ComboBoxComponent {
  modifyComponentForRow() {
    return "color-palettes/color-palettes-row";
  }
}
