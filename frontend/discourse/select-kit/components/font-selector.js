import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "select-kit/components/combo-box";
import FontSelectorRow from "./font-selector/font-selector-row";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";
import SelectedFont from "./selected-font";

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
