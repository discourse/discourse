/*global Mousetrap:true*/

/**
  Initialize Global Keyboard Shortcuts
**/
export default {
  name: "keyboard-shortcuts",
  initialize: function(container) {
    Discourse.KeyboardShortcuts.bindEvents(Mousetrap, container);
  }
};
