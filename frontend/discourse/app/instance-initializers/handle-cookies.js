import { later } from "@ember/runloop";
import { extendColorSchemeCookies } from "discourse/lib/color-scheme-picker";
import { isTesting } from "discourse/lib/environment";
import { extendThemeCookie } from "discourse/lib/theme-selector";
import { extendTextSizeCookie } from "discourse/models/user";

const DELAY = isTesting() ? 0 : 5000;

export default {
  initialize() {
    // No need to block boot for this housekeeping - we can defer it a few seconds
    later(() => {
      extendThemeCookie();
      extendColorSchemeCookies();
      extendTextSizeCookie();
    }, DELAY);
  },
};
