export default {
  name: 'default-i18n',

  initialize: function() {
    // We always prefix with "js." to select exactly what we want passed
    // through to the front end.
    var oldI18nlookup = I18n.lookup;
    I18n.lookup = function(scope, options) {
      return oldI18nlookup.apply(this, ["js." + scope, options]);
    };

    // Default format for storage units
    var oldI18ntoHumanSize = I18n.toHumanSize;
    I18n.toHumanSize = function(number, options) {
      options = options || {};
      options.format = I18n.t("number.human.storage_units.format");
      return oldI18ntoHumanSize.apply(this, [number, options]);
    };

    if (Ember.EXTEND_PROTOTYPES) {
      String.prototype.i18n = function(options) {
        return I18n.t(String(this), options);
      };
    }

  }
};
