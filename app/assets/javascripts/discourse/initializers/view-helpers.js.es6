var helpers = ['input-tip',
               'pagedown-editor',
               'text-field',
               'user-selector',
               'category-chooser',
               'combo-box',
               'choose-topic'];

/**
  Creates view helpers for some views. Many of these should probably be converted
  into components in the long term as it's a better fit.
**/
export default {
  name: 'view-hlpers',
  initialize: function(container) {
    helpers.forEach(function(h) {
      Ember.Handlebars.registerHelper(h, function(options) {
        var helper = container.lookupFactory('view:' + h),
            hash = options.hash,
            types = options.hashTypes;

        Discourse.Utilities.normalizeHash(hash, types);
        return Ember.Handlebars.helpers.view.call(this, helper, options);
      });
    });
  }
};
