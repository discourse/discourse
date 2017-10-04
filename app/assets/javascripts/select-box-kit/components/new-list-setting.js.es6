import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";

export default MultiComboBoxComponent.extend({
  tokenSeparator: "|",


  // settingValue=value choices=setting.choices settingName=setting.setting

  classNames: "new-list-setting",


  content: Ember.computed.alias("choices"),

  init() {
    this._super();

    this.set("content", this.getWithDefault("choices", Ember.A()));
    this.set("value", this.get("settingValue").split(this.get("tokenSeparator")));
  }
});
