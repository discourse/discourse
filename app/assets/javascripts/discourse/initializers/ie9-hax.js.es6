export default {
  name: 'ie9-hacks',
  initialize: function() {
    if (!window) { return; }

    // IE9 does not support a console object unless the developer tools are open
    if (!window.console) { window.console = {}; }
    if (!window.console.log) { window.console.log = Ember.K; }
  }
};
