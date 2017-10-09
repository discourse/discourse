import computed from "ember-addons/ember-computed-decorators";
import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";

export default MultiComboBoxComponent.extend({
  tokenSeparator: "|",

  classNames: "new-list-setting",

  @computed("choices.[]")
  computedContent(choices) {
    return this.formatContents(choices.split(this.get("tokenSeparator")));
  },

  @computed("settingValue")
  computedValue(settingValue) {
    console.log("settingValue", settingValue)
    return settingValue.split(this.get("tokenSeparator"));
  }
});
