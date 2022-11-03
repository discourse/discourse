import { extendThemeCookie } from "discourse/lib/theme-selector";
import { extendColorSchemeCookies } from "discourse/lib/color-scheme-picker";
import { later } from "@ember/runloop";

export default {
  name: "handle-cookies",

  initialize() {
    // No need to block boot for this housekeeping - we can defer it a few seconds
    later(() => {
      extendThemeCookie();
      extendColorSchemeCookies();
    }, 5000);
  },
};
