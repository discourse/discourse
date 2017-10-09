import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import computed from "ember-addons/ember-computed-decorators";

export default SelectBoxKitComponent.extend({
  classNames: "multi-combobox",
  headerComponent: "multi-combo-box/multi-combo-box-header",
  headerText: "select_values",
  value: [],
  computedValue: Ember.computed.alias("value"),

  @computed("none")
  computedNone(none) {
    if (!Ember.isNone(none)) {
      this.set("none", {name: I18n.t(none), value: "none"});
    }
  },

  @computed("computedValue.[]", "computedContent.[]")
  selectedContents(computedValue, computedContent) {
    const contents = [];

    computedValue.forEach(cv => {
      const content = computedContent.findBy("value", cv);
      contents.push(content);
    });

    return contents;
  },

  @computed("content.[]", "selectedContents.[]", "filter")
  filteredContent(content, selectedContents) {
    const filteredContent = this._super();
    const selectedContentsIds = selectedContents.map(c => Ember.get(c, "value") );

    return filteredContent.filter(c => {
      return !selectedContentsIds.includes(Ember.get(c, "value"));
    });
  },

  actions: {
    onClearSelection() {
      this.defaultOnSelect();

      this.set("value", []);
    },

    onSelect(value) {
      this.defaultOnSelect();

      this.get("value").pushObject(value);
    },

    onDeselect(value) {
      this.get("value").removeObject(value);
    }
  }
});
