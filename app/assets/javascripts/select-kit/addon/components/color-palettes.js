import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["color-palettes"],
  classNames: ["color-palettes"],

  modifyComponentForRow() {
    return "color-palettes/color-palettes-row";
  }
});
