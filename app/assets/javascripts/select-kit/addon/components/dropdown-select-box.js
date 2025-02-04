import { classNames } from "@ember-decorators/component";
import SingleSelectComponent from "select-kit/components/single-select";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@classNames("dropdown-select-box")
@selectKitOptions({
  autoFilterable: false,
  filterable: false,
  showFullTitle: true,
  headerComponent: "dropdown-select-box/dropdown-select-box-header",
  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  showCaret: false,
  customStyle: null,
  btnCustomClasses: null,
})
@pluginApiIdentifiers(["dropdown-select-box"])
export default class DropdownSelectBox extends SingleSelectComponent {
  modifyComponentForRow() {
    return "dropdown-select-box/dropdown-select-box-row";
  }
}
