import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";
import { observes } from 'ember-addons/ember-computed-decorators';

export default MultiComboBoxComponent.extend({
  classNames: "list-setting",
  tokenSeparator: "|",
  settingValue: "",
  choices: null,
  filterable: true,

  init() {
    const valuesFromString = this.get("settingValue").split(this.get("tokenSeparator"));
    this.set("value", valuesFromString.reject(v => Ember.isEmpty(v)));

    if (Ember.isNone(this.get("choices"))) {
      this.set("content", valuesFromString);
    }  else {
      this.set("content", this.get("choices"));
    }

    if (!Ember.isNone(this.get("settingName"))) {
      this.set("nameProperty", this.get("settingName"));
    }

    if (Ember.isEmpty(this.get("content"))) {
      this.set("rowComponent", null);
      this.set("noContentLabel", null);
    }

    this._super();

    if (this.get("nameProperty").indexOf("color") > -1) {
      this.set("headerComponentOptions", Ember.Object.create({
        selectedNameComponent: "multi-combo-box/selected-color"
      }));
    }
  },

  @observes("value.[]")
  setSettingValue() {
    this.set("settingValue", this.get("value").join(this.get("tokenSeparator")));
  },

  @observes("content.[]")
  setChoices() { this.set("choices", this.get("content")); },

  _handleTabOnKeyDown(event) {
    if (this.$highlightedRow().length === 1) {
      this._super(event);
    } else {
      this.close();
      return false;
    }
  }
});
