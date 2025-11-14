import { updateRelativeAge } from "discourse/lib/formatter";
import { getOwnerWithFallback } from "discourse/lib/get-owner";

// Updates the relative ages of dates on the screen.
export default {
  initialize() {
    this._interval = setInterval(function () {
      updateRelativeAge(document.querySelectorAll(".relative-date"));
      getOwnerWithFallback(this).lookup(
        "service:a11y"
      ).autoUpdatingRelativeDateRef = new Date();
    }, 60 * 1000);
  },

  teardown() {
    if (this._interval) {
      clearInterval(this._interval);
      this._interval = null;
    }
  },
};
