import { classNames } from "@ember-decorators/component";
import SingleSelectComponent from "select-kit/components/single-select";
import DropdownSelectBoxHeader from "./dropdown-select-box/dropdown-select-box-header";
import DropdownSelectBoxRow from "./dropdown-select-box/dropdown-select-box-row";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit";

@classNames("dropdown-select-box")
@selectKitOptions({
  autoFilterable: false,
  filterable: false,
  showFullTitle: true,
  headerComponent: DropdownSelectBoxHeader,
  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  showCaret: false,
  customStyle: null,
  btnCustomClasses: null,
})
@pluginApiIdentifiers(["dropdown-select-box"])
export default class DropdownSelectBox extends SingleSelectComponent {
  modifyComponentForRow() {
    return DropdownSelectBoxRow;
  }
}
