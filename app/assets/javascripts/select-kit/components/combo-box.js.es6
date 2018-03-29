import SingleSelectComponent from "select-kit/components/single-select";
import { on, default as computed } from "ember-addons/ember-computed-decorators";

export default SingleSelectComponent.extend({
  pluginApiIdentifiers: ["combo-box"],
  classNames: "combobox combo-box",
  autoFilterable: true,
  headerComponent: "combo-box/combo-box-header",

  caretUpIcon: "caret-up fa-fw",
  caretDownIcon: "caret-down fa-fw",
  clearable: false,

  computeHeaderContent() {
    let content = this._super();
    content.hasSelection = this.get("hasSelection");
    return content;
  },

  @computed("isExpanded", "caretUpIcon", "caretDownIcon")
  caretIcon(isExpanded, caretUpIcon, caretDownIcon) {
    return isExpanded ? caretUpIcon : caretDownIcon;
  },

  @on("didReceiveAttrs")
  _setComboBoxOptions() {
    const placeholder = this.get('placeholder');

    this.get("headerComponentOptions").setProperties({
      clearable: this.get("clearable"),
      placeholder: placeholder ? I18n.t(placeholder) : "",
    });
  }
});
