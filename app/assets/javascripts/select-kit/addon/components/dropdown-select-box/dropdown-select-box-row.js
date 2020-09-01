import { readOnly } from "@ember/object/computed";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import layout from "select-kit/templates/components/dropdown-select-box/dropdown-select-box-row";

export default SelectKitRowComponent.extend({
  layout,
  classNames: ["dropdown-select-box-row"],

  description: readOnly("item.description")
});
