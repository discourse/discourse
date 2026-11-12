import { classNames } from "@ember-decorators/component";
import SingleSelectComponent from "discourse/select-kit/components/single-select";
import DropdownSelectBoxHeader from "./dropdown-select-box/dropdown-select-box-header.gjs";
import DropdownSelectBoxRow from "./dropdown-select-box/dropdown-select-box-row.gjs";
import { pluginApiIdentifiers, selectKitOptions } from "./select-kit.js";

@classNames("dropdown-select-box")
@selectKitOptions({
  autoFilterable: false,
  filterable: false,
  showFullTitle: true,
  headerComponent: DropdownSelectBoxHeader,
  caretUpIcon: "angle-up",
  caretDownIcon: "angle-down",
  showCaret: false,
  customStyle: null,
  btnCustomClasses: null,
  headerAriaLabel: null,
})
@pluginApiIdentifiers(["dropdown-select-box"])
export default class DropdownSelectBox extends SingleSelectComponent {
  modifyComponentForRow() {
    return DropdownSelectBoxRow;
  }
}
