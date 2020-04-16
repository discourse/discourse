/*global Mousetrap:true*/
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";

export default {
  name: "keyboard-shortcuts",

  initialize(container) {
    KeyboardShortcuts.init(Mousetrap, container);
    KeyboardShortcuts.bindEvents();
  },

  teardown() {
    KeyboardShortcuts.teardown();
  }
};
