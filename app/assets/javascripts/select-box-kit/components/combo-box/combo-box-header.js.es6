import SelectBoxKitHeaderComponent from "select-box-kit/components/select-box-kit/select-box-kit-header";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default SelectBoxKitHeaderComponent.extend({
  layoutName: "select-box-kit/templates/components/combo-box/combo-box-header",
  classNames: "combo-box-header",

  clearable: Ember.computed.alias("options.clearable"),
  caretUpIcon: Ember.computed.alias("options.caretUpIcon"),
  caretDownIcon: Ember.computed.alias("options.caretDownIcon"),
  selectedName: Ember.computed.alias("options.selectedName"),

  @computed("isExpanded", "caretUpIcon", "caretDownIcon")
  caretIcon(isExpanded, caretUpIcon, caretDownIcon) {
    return isExpanded === true ? caretUpIcon : caretDownIcon;
  },

  @computed("clearable", "selectedContent")
  shouldDisplayClearableButton(clearable, selectedContent) {
    return clearable === true && !Ember.isEmpty(selectedContent);
  },

  @computed("options.selectedName", "selectedContent.firstObject.name", "none.name")
  selectedName(selectedName, name, noneName) {
    if (Ember.isPresent(selectedName)) {
      return selectedName;
    }

    if (Ember.isNone(name)) {
      if (Ember.isNone(noneName)) {
        return this._super();
      } else {
        return noneName;
      }
    } else {
      return name;
    }
  }
});
