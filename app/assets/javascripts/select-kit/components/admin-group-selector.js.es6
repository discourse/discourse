import MultiSelectComponent from "select-kit/components/multi-select";
import computed from "ember-addons/ember-computed-decorators";
const { makeArray } = Ember;

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["admin-group-selector"],
  classNames: "admin-group-selector",
  selected: null,
  available: null,
  allowAny: false,
  buffer: null,

  @computed("buffer")
  values(buffer) {
    return buffer === null
      ? makeArray(this.get("selected")).map(s => this.valueForContentItem(s))
      : buffer;
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
    this.set("buffer", values);
  }
});
