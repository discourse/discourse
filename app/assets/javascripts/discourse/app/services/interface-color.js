import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import cookie, { removeCookie } from "discourse/lib/cookie";

const COOKIE_NAME = "forced_color_mode";
const DARK = "dark";
const LIGHT = "light";

export default class InterfaceColor extends Service {
  @service siteSettings;
  @service session;
  @tracked forcedColorMode;

  get lightModeForced() {
    return this.switcherAvailable && this.forcedColorMode === LIGHT;
  }

  get darkModeForced() {
    return this.switcherAvailable && this.forcedColorMode === DARK;
  }

  get switcherAvailable() {
    return (
      this.session.darkModeAvailable && !this.session.defaultColorSchemeIsDark
    );
  }

  get switcherAvailableInSidebar() {
    return (
      this.switcherAvailable &&
      this.siteSettings.interface_color_switcher === "sidebar_footer"
    );
  }

  get switcherAvailableInHeader() {
    return (
      this.switcherAvailable &&
      this.siteSettings.interface_color_switcher === "header"
    );
  }

  ensureCorrectMode() {
    if (!this.switcherAvailable) {
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
  }

  removeColorModeOverride() {
    this.forcedColorMode = null;
    removeCookie(COOKIE_NAME, { path: "/" });

    const lightStylesheet = this.#lightColorsStylesheet();
    if (lightStylesheet) {
      lightStylesheet.media = "(prefers-color-scheme: light)";
    }

    const darkStylesheet = this.#darkColorsStylesheet();
    if (darkStylesheet) {
      darkStylesheet.media = "(prefers-color-scheme: dark)";
    }
  }

  #lightColorsStylesheet() {
    return document.querySelector("link.light-scheme");
  }

  #darkColorsStylesheet() {
    return document.querySelector("link.dark-scheme");
  }
}
