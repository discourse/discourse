import MultiSelectComponent from "select-kit/components/multi-select";
const { makeArray } = Ember;

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["admin-group-selector"],
  classNames: "admin-group-selector",
  selected: null,
  available: null,
  allowAny: false,

  computeValues() {
    return makeArray(this.get("selected")).map(s =>
      this.valueForContentItem(s)
    );
  },

  computeContent() {
    return makeArray(this.get("available"));
  },

  computeContentItem(contentItem, name) {
    let computedContentItem = this._super(contentItem, name);
    computedContentItem.locked = contentItem.automatic;
    return computedContentItem;
  },

  mutateValues(values) {
    if (values.length > this.get("selected").length) {
      const newValues = values.filter(
        v =>
          !this.get("selected")
            .map(s => this.valueForContentItem(s))
            .includes(v)
      );

      newValues.forEach(value => {
        const actionContext = this.get("available").findBy(
          this.get("valueAttribute"),
          parseInt(value, 10)
        );

        this.triggerAction({ action: "groupAdded", actionContext });
      });
    } else if (values.length < this.get("selected").length) {
      const selected = this.get("selected").filter(
        s => !values.includes(this.valueForContentItem(s))
      );

      selected.forEach(s => {
        this.triggerAction({
          action: "groupRemoved",
          actionContext: this.valueForContentItem(s)
        });
      });
    }
  }
});
