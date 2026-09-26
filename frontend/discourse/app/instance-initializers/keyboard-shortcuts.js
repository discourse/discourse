import { lookup } from "discourse/lib/service";
import KeyboardShortcutsService from "discourse/services/keyboard-shortcuts";
export default {
  initialize(owner) {
    lookup(owner, KeyboardShortcutsService);
  },
};
