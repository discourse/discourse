import SingleSelectComponent from "select-kit/components/single-select";
import { on } from "ember-addons/ember-computed-decorators";

export default SingleSelectComponent.extend({
  pluginApiIdentifiers: ["combo-box"],
  classNames: "combobox combo-box",
  autoFilterable: true,
  headerComponent: "combo-box/combo-box-header",

  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  clearable: false,

  computeHeaderContent() {
    let content = this.baseHeaderComputedContent();
    content.hasSelection = this.get("hasSelection");
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
