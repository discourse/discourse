/**
 We always prefix with "js." to select exactly what we want passed
 through to the front end.
**/
var oldI18nlookup = I18n.lookup;
I18n.lookup = function(scope, options) {
  return oldI18nlookup.apply(this, ["js." + scope, options]);
};

/**
 Default format for storage units
**/
var oldI18ntoHumanSize = I18n.toHumanSize;
I18n.toHumanSize = function(number, options) {
  options = options || {};
  options.format = I18n.t("number.human.storage_units.format");
  return oldI18ntoHumanSize.apply(this, [number, options]);
};

/**
  Look up a translation for an i18n key in our dictionary.

  @method i18n
  @for Handlebars
**/
Handlebars.registerHelper('i18n', function(property, options) {
  // Resolve any properties
  var params = options.hash,
    self = this;

  _.each(params, function(value, key) {
    params[key] = Em.Handlebars.get(self, value, options);
  });

  return I18n.t(property, params);
});

/**
 Bound version of i18n helper.
 **/
Ember.Handlebars.registerBoundHelper("boundI18n", function(property, options) {
  return new Handlebars.SafeString(I18n.t(property, options.hash));
});

/**
  Set up an i18n binding that will update as a count changes, complete with pluralization.

  @method countI18n
  @for Handlebars
**/
Ember.Handlebars.registerHelper('countI18n', function(key, options) {
  var view = Discourse.View.extend({
    tagName: 'span',
    shouldRerender: Discourse.View.renderIfChanged('count', 'suffix'),

    render: function(buffer) {
      buffer.push(I18n.t(key + (this.get('suffix') || ''), { count: this.get('count') }));
    }

  });
  return Ember.Handlebars.helpers.view.call(this, view, options);
});

if (Ember.EXTEND_PROTOTYPES) {
  String.prototype.i18n = function(options) {
    return I18n.t(String(this), options);
  };
}
