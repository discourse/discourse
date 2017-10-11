import computed from "ember-addons/ember-computed-decorators";
import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";

export default MultiComboBoxComponent.extend({
  tokenSeparator: "|",

  classNames: "new-list-setting",

  @computed("choices.[]", "tokenSeparator")
  computedContent(choices, tokenSeparator) {
    return this.formatContents(choices.split(tokenSeparator));
  },

  @computed("settingValue", "tokenSeparator")
  computedValue(settingValue, tokenSeparator) {
    return settingValue.split(tokenSeparator);
  }
});
