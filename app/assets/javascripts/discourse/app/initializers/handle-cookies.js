import { extendThemeCookie } from "discourse/lib/theme-selector";
import { extendColorSchemeCookies } from "discourse/lib/color-scheme-picker";
import { extendTextSizeCookie } from "discourse/models/user";
import { later } from "@ember/runloop";
import { isTesting } from "discourse-common/config/environment";

const DELAY = isTesting() ? 0 : 5000;

export default {
  name: "handle-cookies",

  initialize() {
    // No need to block boot for this housekeeping - we can defer it a few seconds
    later(() => {
      extendThemeCookie();
      extendColorSchemeCookies();
      extendTextSizeCookie();
    }, DELAY);
  },
};
