export default {
  name: 'load-all-helpers',

  initialize: function() {
    Ember.keys(requirejs.entries).forEach(function(entry) {
      if ((/\/helpers\//).test(entry)) {
        require(entry, null, null, true);
      }
    });

    // TODO: Once things have migrated remove these
    if (!Discourse.hasOwnProperty('computed')) {
      const computed = require('discourse/lib/computed');
      Object.defineProperty(Discourse, 'computed', {
        get: function() {
          Ember.warn('DEPRECATION: `Discourse.computed` is deprecated, import the functions as needed.');
          return computed;
        }
      });
    }

    if (!Discourse.hasOwnProperty('Formatter')) {
      const Formatter = require('discourse/lib/formatter');
      Object.defineProperty(Discourse, 'Formatter', {
        get: function() {
          Ember.warn('DEPRECATION: `Discourse.Formatter` is deprecated, import the formatters as needed.');
          return Formatter;
        }
      });
    }


  }
};
