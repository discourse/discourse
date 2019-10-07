import { observes } from "ember-addons/ember-computed-decorators";
import Group from "discourse/models/group";

export default Ember.Component.extend({
  @observes("value")
  _onChange() {
    this.onChange(this.value);
  }
});
