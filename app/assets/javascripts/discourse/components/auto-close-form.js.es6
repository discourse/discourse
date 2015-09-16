import computed from "ember-addons/ember-computed-decorators";
import { observes } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  limited: false,
  autoCloseValid: false,

  @computed("limited")
  autoCloseUnits(limited) {
    const key = limited ? "composer.auto_close.limited.units" : "composer.auto_close.all.units";
    return I18n.t(key);
  },

  @computed("limited")
  autoCloseExamples(limited) {
    const key = limited ? "composer.auto_close.limited.examples" : "composer.auto_close.all.examples";
    return I18n.t(key);
  },

  @observes("autoCloseTime", "limited")
  _updateAutoCloseValid() {
    const limited = this.get("limited"),
          autoCloseTime = this.get("autoCloseTime"),
          isValid = this._isAutoCloseValid(autoCloseTime, limited);
    this.set("autoCloseValid", isValid);
  },

  _isAutoCloseValid(autoCloseTime, limited) {
    const t = (autoCloseTime || "").toString().trim();
    if (t.length === 0) {
      // "empty" is always valid
      return true;
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
