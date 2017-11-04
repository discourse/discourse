import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";

export default MultiComboBoxComponent.extend({
  classNames: "new-admin-group-selector",
  selected: null,
  available: null,
  value: Ember.computed.alias("selected"),
  content: Ember.computed.alias("available"),

  init() {
    this._super();

    this.setProperties({
      selected: this.getWithDefault("selected", []),
      available: this.getWithDefault("available", [])
    });
  },

  actions: {
    onClearSelection() {},

    onSelect(value) {
      this.triggerAction({
        action: "groupAdded",
        actionContext: this.get("content").findBy("id", parseInt(value))
      });
    },

    onDeselect(value) {
      this.defaultOnDeselect(value);
      this.triggerAction({ action: "groupRemoved", actionContext: value });
    }
  }
});
