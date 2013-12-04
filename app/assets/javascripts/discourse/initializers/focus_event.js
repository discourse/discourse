/**
  Keep track of when the browser is in focus.
**/
Discourse.addInitializer(function() {

  // Default to true
  this.set('hasFocus', true);

  var self = this;
  $(window).focus(function() {
    self.setProperties({hasFocus: true, notify: false});
  }).blur(function() {
    self.set('hasFocus', false);
  });

}, true);