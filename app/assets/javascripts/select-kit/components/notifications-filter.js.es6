// import { oneWay, readOnly } from "@ember/object/computed";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: ["notifications-filter"],
  content: ["All","Read","Unread"],
  value: "All",
  isVisible: true,
  valueProperty: null,
  nameProperty: null,

  modifyComponentForRow() {
    return "notifications-filter/notifications-filter-row";
  },

  selectKitOptions: {
    filterable: false,
    autoFilterable: false,
    headerComponent: "notifications-filter/notifications-filter-header"
  },

  actions: {
    onChange(value) {
      this.set('value',value);
      this.attrs.action(value);
    }
  }
});
