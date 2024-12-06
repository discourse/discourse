import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "select-kit/components/combo-box";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@classNames("font-selector")
@pluginApiIdentifiers(["font-selector"])
@selectKitOptions({
  selectedNameComponent: "selected-font",
})
export default class FontSelector extends ComboBoxComponent {
  modifyComponentForRow() {
    return "font-selector/font-selector-row";
  }
}
