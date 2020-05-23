import { oneWay, readOnly } from "@ember/object/computed";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: ["period-chooser"],
  content: oneWay("site.periods"),
  value: readOnly("period"),
  isVisible: readOnly("showPeriods"),
  valueProperty: null,
  nameProperty: null,

  modifyComponentForRow() {
    return "period-chooser/period-chooser-row";
  },

  selectKitOptions: {
    filterable: false,
    autoFilterable: false,
    fullDay: "fullDay",
    headerComponent: "period-chooser/period-chooser-header"
  },

  actions: {
    onChange(value) {
      if (this.action) {
        this.action(value);
      } else {
        this.attrs.onChange && this.attrs.onChange(value);
      }
    }
  }
});
