import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import ItsATrap from "@discourse/itsatrap";

export default {
  initialize(owner) {
    KeyboardShortcuts.init(ItsATrap, owner);
    KeyboardShortcuts.bindEvents();
  },

  teardown() {
    KeyboardShortcuts.teardown();
  },
};
