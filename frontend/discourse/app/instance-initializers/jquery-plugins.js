import $ from "jquery";
import { caret, caretPosition } from "discourse/lib/caret-position";

let jqueryPluginsConfigured = false;

export default {
  initialize() {
    if (jqueryPluginsConfigured) {
      return;
    }

    // Initialize caretPosition
    $.fn.caret = caret;
    $.fn.caretPosition = caretPosition;

    jqueryPluginsConfigured = true;
  },
};
