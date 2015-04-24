import Presence from 'discourse/mixins/presence';

const View = Ember.View.extend(Presence, {});

View.reopenClass({
  registerHelper(helperName, helperClass) {
    Ember.Handlebars.registerHelper(helperName, function(options) {
      var hash = options.hash,
          types = options.hashTypes;

      Discourse.Utilities.normalizeHash(hash, types);
      return Ember.Handlebars.helpers.view.call(this, helperClass, options);
    });
  }
});

export default View;
