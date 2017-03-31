import computed from "ember-addons/ember-computed-decorators";
import { observes } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  limited: false,
  inputValid: false,

  @computed("limited")
  inputUnitsKey(limited) {
    return limited ? "topic.auto_update_input.limited.units" : "topic.auto_update_input.all.units";
  },

  @computed("limited")
  inputExamplesKey(limited) {
    return limited ? "topic.auto_update_input.limited.examples" : "topic.auto_update_input.all.examples";
  },

  @observes("input", "limited")
  _updateInputValid() {
    this.set(
      "inputValid", this._isInputValid(this.get("input"), this.get("limited"))
    );
  },

  _isInputValid(input, limited) {
    const t = (input || "").toString().trim();

    if (t.length === 0) {
      return true;
      // "empty" is always valid
    } else if (limited) {
      // only # of hours in limited mode
      return t.match(/^(\d+\.)?\d+$/);
    } else {
      if (t.match(/^\d{4}-\d{1,2}-\d{1,2}(?: \d{1,2}:\d{2}(\s?[AP]M)?){0,1}$/i)) {
        // timestamp must be in the future
        return moment(t).isAfter();
      } else {
        // either # of hours or absolute time
        return (t.match(/^(\d+\.)?\d+$/) || t.match(/^\d{1,2}:\d{2}(\s?[AP]M)?$/i)) !== null;
      }
    }
  }
});
