import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import Mousetrap from "mousetrap";
import bindGlobal from "mousetrap-global-bind";

export default {
  name: "keyboard-shortcuts",

  initialize(container) {
    // Ensure mousetrap-global-bind is executed
    void bindGlobal;

    KeyboardShortcuts.init(Mousetrap, container);
    KeyboardShortcuts.bindEvents();
  },

  teardown() {
    KeyboardShortcuts.teardown();
  },
};
