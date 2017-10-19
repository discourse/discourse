import SelectBoxKitRowComponent from "select-box-kit/components/select-box-kit/select-box-kit-row";

export default SelectBoxKitRowComponent.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-row",
  classNames: "none",

  click() {
    this.sendAction("onClearSelection");
  }
});
