import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";

export default SelectBoxKitComponent.extend({
  classNames: "dropdown-select-box",
  verticalOffset: 3,
  fullWidthOnMobile: true,
  filterable: false,
  autoFilterable: false,
  headerComponent: "dropdown-select-box/dropdown-select-box-header",
  rowComponent: "dropdown-select-box/dropdown-select-box-row",

  clickOutside() {
    this.close();
  },

  actions: {
    onSelect(value) {
      value = this.defaultOnSelect(value);
      this.set("value", value);

      this.blur();
    }
  }
});
