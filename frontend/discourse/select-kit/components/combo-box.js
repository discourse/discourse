import { gte } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import SingleSelectComponent from "select-kit/components/single-select";
import ComboBoxHeader from "./combo-box/combo-box-header";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@classNames("combobox", "combo-box")
@pluginApiIdentifiers(["combo-box"])
@selectKitOptions({
  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  autoFilterable: "autoFilterable",
  clearable: false,
  headerComponent: ComboBoxHeader,
  shouldDisplayIcon: false,
})
export default class ComboBox extends SingleSelectComponent {
  @gte("content.length", 10) autoFilterable;
}
