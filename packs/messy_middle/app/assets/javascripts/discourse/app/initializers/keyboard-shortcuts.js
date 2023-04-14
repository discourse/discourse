import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import ItsATrap from "@discourse/itsatrap";

export default {
  name: "keyboard-shortcuts",

  initialize(container) {
    KeyboardShortcuts.init(ItsATrap, container);
    KeyboardShortcuts.bindEvents();
  },

  teardown() {
    KeyboardShortcuts.teardown();
  },
};
