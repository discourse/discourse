import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";
import { observes } from "ember-addons/ember-computed-decorators";

export default MultiComboBoxComponent.extend({
  classNames: "group-selector",
  allowAny: false,

  @observes("filter")
  _loadGroups() {
    return this.get("groupFinder")(this.get("filter")).then(groups => {
      this.set("content", groups);
    });
  },

  actions: {
    onSelect(value) {
      this._super(value);
      this.set("groupNames", this.get("value").join(","));
    }
  }
});
