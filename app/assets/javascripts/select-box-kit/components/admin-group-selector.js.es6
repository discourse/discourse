import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";

export default MultiComboBoxComponent.extend({
  classNames: "admin-group-selector",
  selected: null,
  available: null,
  allowAny: false,

  didReceiveAttrs() {
    this._super();

    this.set("value", this.get("selected").map(s => this._valueForContent(s)));
    this.set("content", this.get("available"));
  },

  formatRowContent(content) {
    let formatedContent = this._super(content);
    formatedContent.locked = content.automatic;
    return formatedContent;
  },

  didUpdateAttrs() {
    this._super();

    this.set("highlightedValue", null);
    Ember.run.schedule("afterRender", () => {
      this.autoHighlightFunction();
    });
  },

  selectValuesFunction(values) {
    values.forEach(value => {
      this.triggerAction({
        action: "groupAdded",
        actionContext: this.get("content").findBy("id", parseInt(value, 10))
      });
    });
  },

  deselectValuesFunction(values) {
    values.forEach(value => {
      this.triggerAction({ action: "groupRemoved", actionContext: value });
    });
  }
});
