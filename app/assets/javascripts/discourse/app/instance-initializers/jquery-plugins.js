import $ from "jquery";
import autocomplete from "discourse/lib/autocomplete";
import { caret, caretPosition } from "discourse/lib/caret-position";

let jqueryPluginsConfigured = false;

export default {
  initialize() {
    if (jqueryPluginsConfigured) {
      return;
    }

    // Initialize the autocomplete tool
    $.fn.autocomplete = autocomplete;

    // Initialize caretPosition
    $.fn.caret = caret;
    $.fn.caretPosition = caretPosition;

    jqueryPluginsConfigured = true;
  },
};
