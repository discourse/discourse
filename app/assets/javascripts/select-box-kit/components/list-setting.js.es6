import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";

export default MultiComboBoxComponent.extend({
  classNames: "list-setting",
  tokenSeparator: "|",
  settingValue: "",
  choices: null,
  filterable: true,

  init() {
    this._super();

    if (!Ember.isNone(this.get("settingName"))) {
      this.set("nameProperty", this.get("settingName"));
    }

    if (this.get("nameProperty").indexOf("color") > -1) {
      this.set("headerComponentOptions", Ember.Object.create({
        selectedNameComponent: "multi-combo-box/selected-color"
      }));
    }
  },

  transformInputs() {
    let content;
    const values = this.get("settingValue").split(this.get("tokenSeparator"));
    if (Ember.isNone(this.get("choices"))) {
      content = values;
    }  else {
      content = this.get("choices");
    }

    console.log("transformInputs", content, Ember.makeArray(content))
    this.send("onReceiveContent", Ember.makeArray(content));
    this.send("onReceiveValues", values);
  },

  didLoadContent(content) {
    if (Ember.isEmpty(content)) {
      this.setProperties({ rowComponent: null, noContentLabel: null });
    }
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
