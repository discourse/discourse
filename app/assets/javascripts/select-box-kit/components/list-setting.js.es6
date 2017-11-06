import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";
import { on } from "ember-addons/ember-computed-decorators";

export default MultiComboBoxComponent.extend({
  classNames: "list-setting",
  nameProperty: Ember.computed.alias("setting.setting"),
  tokenSeparator: "|",
  rowComponent: null,
  noContentLabel: null,
  settingValue: "",

  @on("didReceiveAttrs")
  _setValueFromSettingValue() {
    const valuesFromString = this.get("settingValue").split(this.get("tokenSeparator"));
    this.set("value", valuesFromString.reject(v => Ember.isEmpty(v)));
  },

  content: Ember.computed.alias("value"),

  actions: {
    onCreateContent(input) {
      if (this.get("content").includes(input)) { return; }

      input = this.baseOnCreateContent(input);
      const values = this.get("value").concat([input]);
      this.set("value", values);
      this.set("settingValue", this.get("value").join(this.get("tokenSeparator")));
    },

    onDeselect(values) {
      values = this.baseOnDeselect(values).values;
      this.get("value").removeObjects(values);
      this.set("settingValue", this.get("value").join(this.get("tokenSeparator")));
    }
  }
});
