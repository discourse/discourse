import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "discourse/select-kit/components/combo-box";
import FontSelectorRow from "./font-selector/font-selector-row.js";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit.js";
import SelectedFont from "./selected-font.gjs";

@classNames("font-selector")
@pluginApiIdentifiers(["font-selector"])
@selectKitOptions({
  selectedNameComponent: SelectedFont,
})
export default class FontSelector extends ComboBoxComponent {
  modifyComponentForRow() {
    return FontSelectorRow;
  }
}
