import { classNames } from "@ember-decorators/component";
import SingleSelectComponent from "discourse/select-kit/components/single-select";
import ComboBoxHeader from "./combo-box/combo-box-header";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@classNames("combobox", "combo-box")
@pluginApiIdentifiers(["combo-box"])
@selectKitOptions({
  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  clearable: false,
  headerComponent: ComboBoxHeader,
  shouldDisplayIcon: false,
})
export default class ComboBox extends SingleSelectComponent {}
