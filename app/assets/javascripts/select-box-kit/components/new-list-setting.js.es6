import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";
const { isEmpty } = Ember;

export default MultiComboBoxComponent.extend({
  classNames: "new-list-setting",
  nameProperty: Ember.computed.alias("setting.setting"),
  tokenSeparator: "|",

  rowComponent: null,
  noContentLabel: null,

  @computed("settingValue")
  value(settingValue) {
    return settingValue.split(this.get("tokenSeparator"))
                       .reject(setting => isEmpty(setting));
  },

  content: Ember.computed.alias("value"),

  @on("willRender")
  _autoHighlight() {
    this.send("onHighlight", this.get("filter"));
  },


  actions: {
    onClearSelection() {
      this.set("settingValue", "");
    },

    onCreateContent(input) {
      this.setProperties({ highlightedValue: null });

      if (this.get("value").includes(input)) {
        this.$filterInput().focus();
        return;
      }

      const newValues = this.get("value").concat([input]);
      this.setProperties({
        settingValue: newValues.join(this.get("tokenSeparator"))
      });

      this.setProperties({ filter: "", highlightedValue: null });
      this.$filterInput().val("").focus();
    },

    onSelect(value) {
      this.setProperties({ highlightedValue: null });
      console.log("onSelect", value, this.get("value"))
      if (this.get("value").includes(value)) { return; }

      if (this.get("content").includes(value)) {
        const newValues = this.get("value").concat([value]);
        this.set("settingValue", newValues.join(this.get("tokenSeparator")));
      } else {
        this.send("onCreateContent", value);
      }
    },

    onDeselect(value) {
      const currentValues = this.get("settingValue").split(this.get("tokenSeparator"));
      this.set("settingValue", currentValues.removeObject(value).join(this.get("tokenSeparator")));
    }
  }
});
