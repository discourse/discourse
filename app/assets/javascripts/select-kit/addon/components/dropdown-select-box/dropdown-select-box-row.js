import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import { readOnly } from "@ember/object/computed";

export default SelectKitRowComponent.extend({
  classNames: ["dropdown-select-box-row"],
  description: readOnly("item.description"),
});
