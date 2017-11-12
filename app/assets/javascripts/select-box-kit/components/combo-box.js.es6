import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import { on } from "ember-addons/ember-computed-decorators";

export default SelectBoxKitComponent.extend({
  classNames: "combobox combo-box",
  autoFilterable: true,
  headerComponent: "combo-box/combo-box-header",

  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  clearable: false,

  computeHeaderContent() {
    let content = this.baseHeaderComputedContent();

    const noneName = this.get("none.name");
    if (!Ember.isPresent(content.name) && !Ember.isNone(noneName)) {
      content.name = noneName;
    }

    content.hasSelection = this.get("selectedComputedContent").length >= 1;

    return content;
  },

  @on("didReceiveAttrs")
  _setComboBoxOptions() {
    this.get("headerComponentOptions").setProperties({
      caretUpIcon: this.get("caretUpIcon"),
      caretDownIcon: this.get("caretDownIcon"),
      clearable: this.get("clearable"),
    });
  }
});
