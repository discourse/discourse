import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import cookie from "discourse/lib/cookie";
import { INTERFACE_COLOR_MODES } from "discourse/models/user";

const COOKIE_NAME = "forced_color_mode";
const DARK_VALUE_FOR_COOKIE = "dark";
const LIGHT_VALUE_FOR_COOKIE = "light";
const AUTO_VALUE_FOR_COOKIE = "auto";

export default class InterfaceColor extends Service {
  @service appEvents;
  @service currentUser;
  @service siteSettings;
  @service session;

  @tracked colorMode;

  get lightModeForced() {
    return this.selectorAvailable && this.colorModeCookieForcesLight;
  }

  get darkModeForced() {
    return this.selectorAvailable && this.colorModeCookieForcesDark;
  }

  get selectorAvailable() {
    return (
      this.session.darkModeAvailable && !this.session.defaultColorSchemeIsDark
    );
  }

  get colorModeCookieForcesLight() {
    return this.colorMode === LIGHT_VALUE_FOR_COOKIE;
  }

  get colorModeCookieForcesDark() {
    return this.colorMode === DARK_VALUE_FOR_COOKIE;
  }

  get colorModeCookieForcesAuto() {
    return this.colorMode === AUTO_VALUE_FOR_COOKIE;
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

    const cookieValue = cookie(COOKIE_NAME);

    if (cookieValue === AUTO_VALUE_FOR_COOKIE) {
      this.useAutoMode({ adjustStylesheets: false });
    } else if (cookieValue === LIGHT_VALUE_FOR_COOKIE) {
      this.forceLightMode({ flipStylesheets: false });
    } else if (cookieValue === DARK_VALUE_FOR_COOKIE) {
      this.forceDarkMode({ flipStylesheets: false });
    } else if (
      this.currentUser?.user_option?.interface_color_mode ===
      INTERFACE_COLOR_MODES.AUTO
    ) {
      this.colorMode = AUTO_VALUE_FOR_COOKIE;
    } else if (
      this.currentUser?.user_option?.interface_color_mode ===
      INTERFACE_COLOR_MODES.LIGHT
    ) {
      this.colorMode = LIGHT_VALUE_FOR_COOKIE;
    } else if (
      this.currentUser?.user_option?.interface_color_mode ===
      INTERFACE_COLOR_MODES.DARK
    ) {
      this.colorMode = DARK_VALUE_FOR_COOKIE;
    }
  }

  forceLightMode({ flipStylesheets = true } = {}) {
    this.colorMode = LIGHT_VALUE_FOR_COOKIE;
    cookie(COOKIE_NAME, LIGHT_VALUE_FOR_COOKIE, {
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
    this.appEvents.trigger("interface-color:changed", LIGHT_VALUE_FOR_COOKIE);
  }

  forceDarkMode({ flipStylesheets = true } = {}) {
    this.colorMode = DARK_VALUE_FOR_COOKIE;
    cookie(COOKIE_NAME, DARK_VALUE_FOR_COOKIE, {
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
    this.appEvents.trigger("interface-color:changed", DARK_VALUE_FOR_COOKIE);
  }

  useAutoMode({ adjustStylesheets = true } = {}) {
    this.colorMode = AUTO_VALUE_FOR_COOKIE;
    cookie(COOKIE_NAME, AUTO_VALUE_FOR_COOKIE, {
      path: "/",
      expires: 365,
    });

    if (adjustStylesheets) {
      const lightStylesheet = this.#lightColorsStylesheet();
      if (lightStylesheet) {
        lightStylesheet.media = "(prefers-color-scheme: light)";
        this.appEvents.trigger(
          "interface-color:changed",
          LIGHT_VALUE_FOR_COOKIE
        );
      }

      const darkStylesheet = this.#darkColorsStylesheet();
      if (darkStylesheet) {
        darkStylesheet.media = "(prefers-color-scheme: dark)";
        this.appEvents.trigger(
          "interface-color:changed",
          DARK_VALUE_FOR_COOKIE
        );
      }
    }
  }

  #lightColorsStylesheet() {
    return document.querySelector("link.light-scheme");
  }

  #darkColorsStylesheet() {
    return document.querySelector("link.dark-scheme");
  }
}
