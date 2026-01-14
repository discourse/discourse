import { classNames } from "@ember-decorators/component";
import ColorPalettePickerRow from "./color-palette-picker/color-palette-picker-row";
import ComboBox from "./combo-box";
import { pluginApiIdentifiers } from "./select-kit";

@classNames("color-palette-picker")
@pluginApiIdentifiers(["color-palette-picker"])
export default class ColorPalettePicker extends ComboBox {
  modifyComponentForRow() {
    return ColorPalettePickerRow;
  }
}
