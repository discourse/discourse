import { extendColorSchemeCookies } from "discourse/lib/color-scheme-picker";
import { extendThemeCookie } from "discourse/lib/theme-selector";
import { extendTextSizeCookie } from "discourse/models/user";

export default {
  initialize() {
    extendThemeCookie();
    extendColorSchemeCookies();
    extendTextSizeCookie();
  },
};
