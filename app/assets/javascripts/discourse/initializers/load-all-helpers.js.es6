export default {
  name: 'load-all-helpers',

  initialize: function() {
    Ember.keys(requirejs.entries).forEach(function(entry) {
      if ((/\/helpers\//).test(entry)) {
        require(entry, null, null, true);
      }
    });
  }
};

