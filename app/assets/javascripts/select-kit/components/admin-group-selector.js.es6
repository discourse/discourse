import MultiSelectComponent from "select-kit/components/multi-select";
const { makeArray } = Ember;

export default MultiSelectComponent.extend({
  classNames: "admin-group-selector",
  selected: null,
  available: null,
  allowAny: false,

  computeValues() {
    return makeArray(this.get("selected"))
      .map(s => this._valueForContent(s));
  },

  computeContent() {
    return makeArray(this.get("available"));
  },

  formatContentItem(content) {
    let formatedContent = this._super(content);
    formatedContent.locked = content.automatic;
    return formatedContent;
  },

  computeContentItem(contentItem, name) {
    let computedContent = this.baseComputedContentItem(contentItem, name);
    computedContent.locked = contentItem.automatic;
    return computedContent;
  },

  mutateValues(values) {
    if (values.length > this.get("selected").length) {
      const newValues = values.filter(v => !this.get("selected").map(s => s.id).includes(v));
      newValues.forEach(value => {
        this.triggerAction({
          action: "groupAdded",
          actionContext: this.get("available").findBy("id", parseInt(value, 10))
        });
      });
    } else if (values.length < this.get("selected").length) {
      const selected = this.get("selected").filter(s => !values.includes(s.id));
      selected.forEach(s => {
        this.triggerAction({ action: "groupRemoved", actionContext: s.id });
      });
    }
  }
});
