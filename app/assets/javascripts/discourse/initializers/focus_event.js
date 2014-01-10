/**
  Keep track of when the browser is in focus,
  and whether this instance is the least recently used instance of this page.
**/
Discourse.addInitializer(function() {

  // Default to true
  this.set('hasFocus', true);

  var self = this;
  $(window).focus(function() {
    console.log(new Date(), 'focused');
    self.setProperties({hasFocus: true, notify: false});
    self.KeyValueStore.set({key:"lastActiveInstance", value: self.get('instanceId')});
    self.set('isLastActiveInstance', true);
  }).blur(function() {
    console.log(new Date(), 'blurred');
    self.set('hasFocus', false);
  });

  // Generate random window id
  this.set('instanceId', Math.random().toString().substring(2));
  this.set('isLastActiveInstance', true);

  // Add listener
  this.KeyValueStore.listen("lastActiveInstance", function(oldVal, newVal){
    var id = Discourse.get('instanceId');
    if (oldVal === id && newVal !== id) {
      self.set('isLastActiveInstance', false);
    } // else nothing changed
  });

}, true);
