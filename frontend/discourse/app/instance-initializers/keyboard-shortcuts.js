import { lazyLookup } from "discourse/lib/service";

const KEY_EVENTS = ["keydown", "keypress", "keyup"];

// The service binds its shortcuts when it is instantiated. It loads on the
// first key event, which is then replayed so that key press still counts.
export default {
  initialize(owner) {
    const start = (event) => {
      for (const name of KEY_EVENTS) {
        document.removeEventListener(name, start, true);
      }

      lazyLookup(
        owner,
        () => import("discourse/services/keyboard-shortcuts")
      ).then(() =>
        document.dispatchEvent(new KeyboardEvent(event.type, event))
      );
    };

    for (const name of KEY_EVENTS) {
      document.addEventListener(name, start, true);
    }
  },
};
