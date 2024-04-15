import ItsATrap from "@discourse/itsatrap";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";

export default {
  initialize(owner) {
    KeyboardShortcuts.init(ItsATrap, owner);
    KeyboardShortcuts.bindEvents();
  },

  teardown() {
    KeyboardShortcuts.teardown();
  },
};
