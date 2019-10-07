import { observes } from "ember-addons/ember-computed-decorators";
import Group from "discourse/models/group";

export default Ember.Component.extend({
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: false });
  },

  @observes("value")
  _onChange() {
    this.onChange(this.value);
  }
});
