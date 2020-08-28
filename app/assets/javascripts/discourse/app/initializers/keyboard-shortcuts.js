import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import Mousetrap from "mousetrap";

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
