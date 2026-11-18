import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import Service, { service } from "@ember/service";
import discourseDebounce from "discourse/lib/debounce";
import EmbedMode from "discourse/lib/embed-mode";

const STORAGE_KEY = "page-shell-panels";
const STORAGE_VERSION = 1;
const LEGACY_HIDDEN_KEY = "sidebar-hidden";
const PANEL_MODES = ["open", "rail", "hidden"];
const PANEL_FIELDS = [
  "navigation",
  "context",
  "navigationWidth",
  "contextWidth",
];
export const PANEL_LIMITS = {
  navigation: { defaultWidth: 260, minWidth: 200, maxWidth: 400 },
  context: { defaultWidth: 300, minWidth: 200, maxWidth: 1000 },
};

/**
 * Validates one stored panel preference, falling back per field.
 *
 * @param {string} name - `navigation` or `context`.
 * @param {unknown} stored - The stored value for that panel.
 * @param {string} fallbackMode - Mode to use when the stored one is invalid.
 * @returns {{ mode: string, width: number }}
 */
function parsePanelPreference(name, stored, fallbackMode = "open") {
  const { defaultWidth, minWidth, maxWidth } = PANEL_LIMITS[name];
  const mode =
    PANEL_MODES.includes(stored?.mode) &&
    (name === "navigation" || stored.mode !== "rail")
      ? stored.mode
      : fallbackMode;
  const width =
    typeof stored?.width === "number" && Number.isFinite(stored.width)
      ? Math.round(Math.max(minWidth, Math.min(stored.width, maxWidth)))
      : defaultWidth;
  return { mode, width };
}

// Temporary layout controls. This is deliberately not the route/panel API.
// Shell width and footer placement are site policy, so only panel
// preferences persist.
export default class PageShell extends Service {
  @service keyValueStore;
  @service router;
  @service siteSettings;

  @tracked width = "centered";
  @tracked resize = "content";
  @tracked navigation;
  @tracked context;
  @tracked footer = "content";
  @tracked navigationWidth;
  @tracked contextWidth;
  @tracked navigationMaxWidth = PANEL_LIMITS.navigation.maxWidth;
  @tracked contextMaxWidth = Math.max(200, Math.min(1000, window.innerWidth));
  @tracked compactLogo = false;
  @tracked closingPanels = {};
  @tracked animatingPanels = false;

  #animationTimer;

  constructor() {
    super(...arguments);
    this.#load();
  }

  willDestroy() {
    cancel(this.#animationTimer);
    super.willDestroy(...arguments);
  }

  get effectiveNavigationWidth() {
    return Math.min(this.navigationWidth, this.navigationMaxWidth);
  }

  get effectiveContextWidth() {
    return Math.min(this.contextWidth, this.contextMaxWidth);
  }

  get enabled() {
    return (
      this.siteSettings.enable_page_shell_prototype &&
      this.siteSettings.enable_main_outlet_grid_layout_change &&
      !EmbedMode.enabled
    );
  }

  get hasContextPanel() {
    return !this.router.currentRouteName?.includes("preferences");
  }

  /**
   * Applies a control's value. Range inputs update live on `input` and save
   * on `change`, so a drag writes storage once.
   */
  @action
  change(event) {
    const { name, value } = event.target;
    const choices = {
      width: ["centered", "full"],
      resize: ["content", "grow"],
      footer: ["content", "row", "off"],
    };

    if (name === "navigation" || name === "context") {
      if (
        !PANEL_MODES.includes(value) ||
        (name === "context" && value === "rail")
      ) {
        return;
      }
      this.#setPanelMode(name, value);
    } else if (choices[name]?.includes(value)) {
      this.#stopPanelAnimation();
      this[name] = value;
    } else if (name === "navigationWidth" || name === "contextWidth") {
      const size = Number(value);
      if (Number.isFinite(size)) {
        this.#stopPanelAnimation();
        const maximum =
          name === "contextWidth"
            ? this.contextMaxWidth
            : PANEL_LIMITS.navigation.maxWidth;
        this[name] = Math.max(200, Math.min(size, maximum));
      }
    } else {
      return;
    }

    if (event.type === "change" && PANEL_FIELDS.includes(name)) {
      this.#save();
    }
  }

  /**
   * Shows a width while a panel is being dragged, without saving it.
   *
   * @param {"navigation"|"context"} panel
   * @param {number} width
   */
  previewPanelWidth(panel, width) {
    this[`${panel}Width`] = width;
  }

  /**
   * Keeps the width a drag ended on as the panel's preference.
   *
   * @param {"navigation"|"context"} panel
   * @param {number} width
   */
  commitPanelWidth(panel, width) {
    this[`${panel}Width`] = width;
    this.#save();
  }

  @action
  toggleNavigation() {
    this.#setPanelMode(
      "navigation",
      this.navigation === "open" ? "hidden" : "open"
    );
    this.#save();
  }

  @action
  openNavigation() {
    this.#setPanelMode("navigation", "open");
    this.#save();
  }

  @action
  toggleContext() {
    this.#setPanelMode("context", this.context === "open" ? "hidden" : "open");
    this.#save();
  }

  #setPanelMode(panel, mode) {
    const previousMode = this[panel];
    if (previousMode === mode) {
      return;
    }

    if (
      this.width === "centered" &&
      window.matchMedia("(prefers-reduced-motion: no-preference)").matches
    ) {
      this.closingPanels = {
        ...this.closingPanels,
        [panel]: mode === "hidden" ? previousMode : undefined,
      };
      this.animatingPanels = true;
      this.#animationTimer = discourseDebounce(
        this,
        this.#stopPanelAnimation,
        250
      );
    }

    this[panel] = mode;
  }

  #stopPanelAnimation() {
    if (!this.animatingPanels) {
      return;
    }

    cancel(this.#animationTimer);
    this.animatingPanels = false;
    this.closingPanels = {};
  }

  #load() {
    let stored = this.keyValueStore.getObject(STORAGE_KEY);
    if (stored?.version !== STORAGE_VERSION) {
      stored = null;
    }
    // Without a saved shell preference, start from the legacy sidebar choice.
    const navigationFallback =
      !stored && this.keyValueStore.getItem(LEGACY_HIDDEN_KEY)
        ? "hidden"
        : "open";
    const navigation = parsePanelPreference(
      "navigation",
      stored?.navigation,
      navigationFallback
    );
    const context = parsePanelPreference("context", stored?.context);

    this.navigation = navigation.mode;
    this.navigationWidth = navigation.width;
    this.context = context.mode;
    this.contextWidth = context.width;
  }

  #save() {
    this.keyValueStore.setObject({
      key: STORAGE_KEY,
      value: {
        version: STORAGE_VERSION,
        navigation: { mode: this.navigation, width: this.navigationWidth },
        context: { mode: this.context, width: this.contextWidth },
      },
    });

    // Keeps the legacy layout's choice in step while the shell can be turned off.
    if (this.navigation === "hidden") {
      this.keyValueStore.setItem(LEGACY_HIDDEN_KEY, "true");
    } else {
      this.keyValueStore.removeItem(LEGACY_HIDDEN_KEY);
    }
  }
}
