import SingleSelectComponent from "select-kit/components/single-select";
import { on } from "ember-addons/ember-computed-decorators";

export default SingleSelectComponent.extend({
  classNames: "combobox combo-box",
  autoFilterable: true,
  headerComponent: "combo-box/combo-box-header",

  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  clearable: false,

  computeHeaderContent() {
    let content = this.baseHeaderComputedContent();

    const noneName = this.get("noneRowComputedContent.name");
    if (Ember.isEmpty(content.name) && !Ember.isNone(noneName)) {
      content.name = noneName;
    }
    content.hasSelection = !Ember.isEmpty(this.get("selectedComputedContent"));

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
