import { readOnly } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("dropdown-select-box-row")
export default class DropdownSelectBoxRow extends SelectKitRowComponent {
  @readOnly("item.description") description;
}
