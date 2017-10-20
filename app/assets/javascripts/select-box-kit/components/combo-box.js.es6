import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import { on } from "ember-addons/ember-computed-decorators";

export default SelectBoxKitComponent.extend({
  classNames: "combobox combo-box",
  autoFilterable: true,
  headerComponent: "combo-box/combo-box-header",

  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  clearable: false,

  @on("didReceiveAttrs")
  _setComboBoxOptions() {
    this.set("headerComponentOptions", Ember.Object.create({
      caretUpIcon: this.get("caretUpIcon"),
      caretDownIcon: this.get("caretDownIcon"),
      clearable: this.get("clearable"),
    }));
  }
});
