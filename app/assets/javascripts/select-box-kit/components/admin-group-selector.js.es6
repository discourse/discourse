import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";
const { makeArray } = Ember;

export default MultiComboBoxComponent.extend({
  classNames: "admin-group-selector",
  selected: null,
  available: null,
  allowAny: false,

  loadValuesFunction() {
    return makeArray(this.get("selected")).map(s => this._valueForContent(s));
  },

  loadContentFunction() { return makeArray(this.get("available")); },

  formatContentItem(content) {
    let formatedContent = this._super(content);
    formatedContent.locked = content.automatic;
    return formatedContent;
  },

  // didUpdateAttrs() {
  //   this._super();
  //
  //   this.set("highlightedValue", null);
  //   Ember.run.schedule("afterRender", () => {
  //     this.autoHighlight();
  //   });
  // },

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
