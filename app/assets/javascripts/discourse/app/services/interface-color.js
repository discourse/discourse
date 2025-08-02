import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import cookie, { removeCookie } from "discourse/lib/cookie";

const COOKIE_NAME = "forced_color_mode";
const DARK = "dark";
const LIGHT = "light";

export default class InterfaceColor extends Service {
  @service appEvents;
  @service siteSettings;
  @service session;

  @tracked forcedColorMode;

  get lightModeForced() {
    return this.selectorAvailable && this.forcedColorMode === LIGHT;
  }

  get darkModeForced() {
    return this.selectorAvailable && this.forcedColorMode === DARK;
  }

  get selectorAvailable() {
    return (
      this.session.darkModeAvailable && !this.session.defaultColorSchemeIsDark
    );
  }

  get selectorAvailableInSidebar() {
    return (
      this.selectorAvailable &&
      this.siteSettings.interface_color_selector === "sidebar_footer"
    );
  }

  get selectorAvailableInHeader() {
    return (
      this.selectorAvailable &&
      this.siteSettings.interface_color_selector === "header"
    );
  }

  ensureCorrectMode() {
    if (!this.selectorAvailable) {
      return;
    }

    const forcedColorMode = cookie(COOKIE_NAME);

    if (forcedColorMode === LIGHT) {
      this.forceLightMode({ flipStylesheets: false });
    } else if (forcedColorMode === DARK) {
      this.forceDarkMode({ flipStylesheets: false });
    }
  }

  forceLightMode({ flipStylesheets = true } = {}) {
    this.forcedColorMode = LIGHT;
    cookie(COOKIE_NAME, LIGHT, {
      path: "/",
      expires: 365,
    });

    if (flipStylesheets) {
      const lightStylesheet = this.#lightColorsStylesheet();
      const darkStylesheet = this.#darkColorsStylesheet();
      if (lightStylesheet && darkStylesheet) {
        lightStylesheet.media = "all";
        darkStylesheet.media = "none";
      }
    }
    this.appEvents.trigger("interface-color:changed", LIGHT);
  }

  forceDarkMode({ flipStylesheets = true } = {}) {
    this.forcedColorMode = DARK;
    cookie(COOKIE_NAME, DARK, {
      path: "/",
      expires: 365,
    });

    if (flipStylesheets) {
      const lightStylesheet = this.#lightColorsStylesheet();
      const darkStylesheet = this.#darkColorsStylesheet();
      if (lightStylesheet && darkStylesheet) {
        lightStylesheet.media = "none";
        darkStylesheet.media = "all";
      }
    }
    this.appEvents.trigger("interface-color:changed", DARK);
  }

  removeColorModeOverride() {
    this.forcedColorMode = null;
    removeCookie(COOKIE_NAME, { path: "/" });

    const lightStylesheet = this.#lightColorsStylesheet();
    if (lightStylesheet) {
      lightStylesheet.media = "(prefers-color-scheme: light)";
      this.appEvents.trigger("interface-color:changed", LIGHT);
    }

    const darkStylesheet = this.#darkColorsStylesheet();
    if (darkStylesheet) {
      darkStylesheet.media = "(prefers-color-scheme: dark)";
      this.appEvents.trigger("interface-color:changed", DARK);
    }
  }

  #lightColorsStylesheet() {
    return document.querySelector("link.light-scheme");
  }

  #darkColorsStylesheet() {
    return document.querySelector("link.dark-scheme");
  }
}
