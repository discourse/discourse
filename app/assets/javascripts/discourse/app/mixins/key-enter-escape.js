import { isiPad } from "discourse/lib/utilities";

// A mixin where hitting ESC calls `cancelled` and ctrl+enter calls `save.
export default {
  keyDown(e) {
    if (e.which === 27) {
      this.cancelled();
      return false;
    } else if (
      e.which === 13 &&
      (e.ctrlKey || e.metaKey || (isiPad() && e.altKey))
    ) {
      // CTRL+ENTER or CMD+ENTER
      //
      // iPad physical keyboard does not offer Command or Control detection
      // so use ALT-ENTER
      this.save();
      return false;
    }
  }
};
