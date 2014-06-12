var deprecatedViewHelpers = {
  inputTip: 'input-tip',
  pagedown: 'pagedown-editor',
  textField: 'text-field',
  userSelector: 'user-selector',
  combobox: 'combo-box',
  categoryChooser: 'category-chooser',
  chooseTopic: 'choose-topic'
};

export default {
  name: 'deprecations',
  initialize: function(container) {
    Ember.keys(deprecatedViewHelpers).forEach(function(old) {
      var newName = deprecatedViewHelpers[old];
      Ember.Handlebars.registerHelper(old, function(options) {
        Em.warn("The `" + old +"` helper is deprecated. Use `" + newName + "` instead.");
        var helper = container.lookupFactory('view:' + newName);
        var hash = options.hash,
            types = options.hashTypes;

        Discourse.Utilities.normalizeHash(hash, types);
        return Ember.Handlebars.helpers.view.call(this, helper, options);
      });
    });
  }
};
