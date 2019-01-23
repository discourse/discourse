import SingleSelectComponent from "select-kit/components/single-select";
import {
  on,
  default as computed
} from "ember-addons/ember-computed-decorators";

export default SingleSelectComponent.extend({
  pluginApiIdentifiers: ["combo-box"],
  classNames: "combobox combo-box",
  autoFilterable: true,
  headerComponent: "combo-box/combo-box-header",

  caretUpIcon: "caret-up",
  caretDownIcon: "caret-down",
  clearable: false,

  computeHeaderContent() {
    let content = this._super(...arguments);
    content.hasSelection = this.get("hasSelection");
    return content;
  },

  @computed("isExpanded", "caretUpIcon", "caretDownIcon")
  caretIcon(isExpanded, caretUpIcon, caretDownIcon) {
    return isExpanded ? caretUpIcon : caretDownIcon;
  },

  @on("didReceiveAttrs")
  _setComboBoxOptions() {
    this.get("headerComponentOptions").setProperties({
      clearable: this.get("clearable")
    });
  }
});
