import Component from "@ember/component";
import { action, computed } from "@ember/object";

export default Component.extend({
  tokenSeparator: "|",

  settingValue: computed("value", function () {
    return this.value.toString().split(this.tokenSeparator).filter(Boolean);
  }),

  settingChoices: computed("setting.choices.[]", "settingValue", function () {
    let choices = this.setting.choices;

    if (this.settingValue) {
      const valuesSet = new Set(choices.map((choice) => choice.value));

      choices = choices.concat(
        this.settingValue
          .filter((value) => !valuesSet.has(value))
          .map((value) => ({ name: value, value }))
      );
    }

    return choices;
  }),

  @action
  onChangeListSetting(value) {
    this.set("value", value.join(this.tokenSeparator));
  },
});
