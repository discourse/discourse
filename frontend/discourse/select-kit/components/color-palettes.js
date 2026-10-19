import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";
import ColorPalettesRow from "./color-palettes/color-palettes-row.gjs";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit.js";

@classNames("color-palettes")
@selectKitOptions({
  translatedNone: i18n("admin.customize.theme.default_light_scheme"),
})
@pluginApiIdentifiers(["color-palettes"])
export default class ColorPalettes extends ComboBoxComponent {
  modifyComponentForRow() {
    return ColorPalettesRow;
  }
}
