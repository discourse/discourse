import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default SelectKitHeaderComponent.extend({
  layoutName: "select-kit/templates/components/combo-box/combo-box-header",
  classNames: "combo-box-header",

  clearable: Ember.computed.alias("options.clearable"),
  caretUpIcon: Ember.computed.alias("options.caretUpIcon"),
  caretDownIcon: Ember.computed.alias("options.caretDownIcon"),

  @computed("isExpanded", "caretUpIcon", "caretDownIcon")
  caretIcon(isExpanded, caretUpIcon, caretDownIcon) {
    return isExpanded === true ? caretUpIcon : caretDownIcon;
  },

  @computed("clearable", "computedContent.hasSelection")
  shouldDisplayClearableButton(clearable, hasSelection) {
    return clearable === true && hasSelection === true;
  }
});
