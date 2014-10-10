export default Ember.Component.extend({
  autoCloseValid: false,
  limited: false,

  autoCloseUnits: function() {
    var key = this.get("limited") ? "composer.auto_close.limited.units"
                                  : "composer.auto_close.all.units";
    return I18n.t(key);
  }.property("limited"),

  autoCloseExamples: function() {
    var key = this.get("limited") ? "composer.auto_close.limited.examples"
                                  : "composer.auto_close.all.examples";
    return I18n.t(key);
  }.property("limited"),

  _updateAutoCloseValid: function() {
    var isValid = this._isAutoCloseValid(this.get("autoCloseTime"), this.get("limited"));
    this.set("autoCloseValid", isValid);
  }.observes("autoCloseTime", "limited"),

  _isAutoCloseValid: function(autoCloseTime, limited) {
    var t = (autoCloseTime || "").trim();
    if (t.length === 0) {
      // "empty" is always valid
      return true;
    } else if (limited) {
      // only # of hours in limited mode
      return t.match(/^(\d+\.)?\d+$/);
    } else {
      if (t.match(/^\d{4}-\d{1,2}-\d{1,2} \d{1,2}:\d{2}(\s?[AP]M)?$/i)) {
        // timestamp must be in the future
        return moment(t).isAfter();
      } else {
        // either # of hours or absolute time
        return (t.match(/^(\d+\.)?\d+$/) || t.match(/^\d{1,2}:\d{2}(\s?[AP]M)?$/i)) !== null;
      }
    }
  }
});
