import { classNames } from "@ember-decorators/component";
import ColorPalettePickerRow from "./color-palette-picker/color-palette-picker-row.gjs";
import ComboBox from "./combo-box.js";
import { pluginApiIdentifiers } from "./select-kit.js";

@classNames("color-palette-picker")
@pluginApiIdentifiers(["color-palette-picker"])
export default class ColorPalettePicker extends ComboBox {
  modifyComponentForRow() {
    return ColorPalettePickerRow;
  }
}
