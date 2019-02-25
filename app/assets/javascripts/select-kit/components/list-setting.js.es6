import MultiSelectComponent from "select-kit/components/multi-select";
const { isNone, makeArray } = Ember;

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["list-setting"],
  classNames: "list-setting",
  tokenSeparator: "|",
  settingValue: "",
  choices: null,
  filterable: true,

  init() {
    this._super(...arguments);

    if (!isNone(this.get("settingName"))) {
      this.set("nameProperty", this.get("settingName"));
    }

    if (this.get("nameProperty").indexOf("color") > -1) {
      this.get("headerComponentOptions").setProperties({
        selectedNameComponent: "multi-select/selected-color"
      });
    }
  },

  computeContent() {
    let content;
    if (isNone(this.get("choices"))) {
      content = this.get("settingValue").split(this.get("tokenSeparator"));
    } else {
      content = this.get("choices");
    }

    return makeArray(content).filter(c => c);
  },

  mutateValues(values) {
    this.set("settingValue", values.join(this.get("tokenSeparator")));
  },

  computeValues() {
    return this.get("settingValue")
      .split(this.get("tokenSeparator"))
      .filter(c => c);
  },

  _handleTabOnKeyDown(event) {
    if (this.$highlightedRow().length === 1) {
      this._super(event);
    } else {
      this.close();
      return false;
    }
  }
});
