import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";

export default MultiComboBoxComponent.extend({
  classNames: "new-admin-group-selector",
  selected: null,
  available: null,
  value: Ember.computed.alias("selected"),
  content: Ember.computed.alias("available"),
  allowAny: false,

  init() {
    this._super();

    this.setProperties({
      selected: this.getWithDefault("selected", []),
      available: this.getWithDefault("available", [])
    });
  },


  formatRowContent(content) {
    let formatedContent = this._super(content);
    formatedContent.locked = content.automatic;
    return formatedContent;
  },

  actions: {
    onSelect(value) {
      value = this.baseOnSelect(value);

      this.triggerAction({
        action: "groupAdded",
        actionContext: this.get("content").findBy("id", parseInt(value))
      });
    },

    onDeselect(values) {
      const deselectState = this.baseOnDeselect(values);
      deselectState.values.forEach(value => {
        this.triggerAction({ action: "groupRemoved", actionContext: value });
      });
    }
  }
});
