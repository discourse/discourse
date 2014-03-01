/**
  Default settings for bootbox
**/
Discourse.addInitializer(function() {

  bootbox.animate(false);

  // clicking outside a bootbox modal closes it
  bootbox.backdrop(true);

}, true);