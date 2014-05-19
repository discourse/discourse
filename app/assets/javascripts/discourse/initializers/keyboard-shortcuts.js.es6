/*global Mousetrap:true*/

/**
  Initialize Global Keyboard Shortcuts
**/
export default {
  name: "keyboard-shortcuts",
  initialize: function() {
    Discourse.KeyboardShortcuts.bindEvents(Mousetrap);
  }
};
