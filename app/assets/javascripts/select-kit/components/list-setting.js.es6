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

    if (!isNone(this.settingName)) {
      this.set("nameProperty", this.settingName);
    }

    if (this.nameProperty.indexOf("color") > -1) {
      this.headerComponentOptions.setProperties({
        selectedNameComponent: "multi-select/selected-color"
      });
    }
  },

  computeContent() {
    let content;
    if (isNone(this.choices)) {
      content = this.settingValue.split(this.tokenSeparator);
    } else {
      content = this.choices;
    }

    return makeArray(content).filter(c => c);
  },

  mutateValues(values) {
    this.set("settingValue", values.join(this.tokenSeparator));
  },

  computeValues() {
    return this.settingValue.split(this.tokenSeparator).filter(c => c);
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
