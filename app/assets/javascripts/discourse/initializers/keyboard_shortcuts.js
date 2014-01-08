/*global Mousetrap:true*/

/**
  Initialize Global Keyboard Shortcuts
**/
Discourse.addInitializer(function() {
  Discourse.KeyboardShortcuts.bindEvents(Mousetrap);
});
