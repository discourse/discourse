export function loadAllHelpers() {
  Ember.keys(requirejs.entries).forEach(entry => {
    if ((/\/helpers\//).test(entry)) {
      require(entry, null, null, true);
    }
  });
}

export default {
  name: 'load-all-helpers',
  initialize: loadAllHelpers
};
