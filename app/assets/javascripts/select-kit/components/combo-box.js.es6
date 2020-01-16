import SingleSelectComponent from "select-kit/components/single-select";
import discourseComputed, { on } from "discourse-common/utils/decorators";

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
    content.hasSelection = this.hasSelection;
    return content;
  },

  @discourseComputed("isExpanded", "caretUpIcon", "caretDownIcon")
  caretIcon(isExpanded, caretUpIcon, caretDownIcon) {
    return isExpanded ? caretUpIcon : caretDownIcon;
  },

  @on("didUpdateAttrs", "init")
  _setComboBoxOptions() {
    this.headerComponentOptions.setProperties({
      clearable: this.clearable
    });
  }
});
