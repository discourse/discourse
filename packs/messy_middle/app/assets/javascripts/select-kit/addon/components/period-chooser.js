import { oneWay, readOnly } from "@ember/object/computed";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";

export default DropdownSelectBoxComponent.extend({
  classNames: ["period-chooser"],
  classNameBindings: ["showPeriods::hidden"],
  content: oneWay("site.periods"),
  value: readOnly("period"),
  valueProperty: null,
  nameProperty: null,
  showPeriods: true,

  modifyComponentForRow() {
    return "period-chooser/period-chooser-row";
  },

  selectKitOptions: {
    filterable: false,
    autoFilterable: false,
    fullDay: "fullDay",
    customStyle: true,
    headerComponent: "period-chooser/period-chooser-header",
    headerAriaLabel: I18n.t("period_chooser.aria_label"),
  },

  actions: {
    onChange(value) {
      if (this.action) {
        this.action(value);
      } else {
        this.attrs.onChange && this.attrs.onChange(value);
      }
    },
  },
});
