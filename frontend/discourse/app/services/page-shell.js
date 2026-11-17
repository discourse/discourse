import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
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
const PANELS = {
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
  const { defaultWidth, minWidth, maxWidth } = PANELS[name];
  const mode = PANEL_MODES.includes(stored?.mode) ? stored.mode : fallbackMode;
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
  @tracked navigation;
  @tracked context;
  @tracked footer = "content";
  @tracked navigationWidth;
  @tracked contextWidth;
  @tracked contextMaxWidth = Math.max(200, Math.min(1000, window.innerWidth));
  @tracked compactLogo = false;

  constructor() {
    super(...arguments);
    this.#load();
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
      navigation: ["open", "rail", "hidden"],
      context: ["open", "rail", "hidden"],
      footer: ["content", "row", "off"],
    };

    if (choices[name]?.includes(value)) {
      this[name] = value;
    } else if (name === "navigationWidth" || name === "contextWidth") {
      const size = Number(value);
      if (Number.isFinite(size)) {
        const maximum =
          name === "contextWidth"
            ? this.contextMaxWidth
            : PANELS.navigation.maxWidth;
        this[name] = Math.max(200, Math.min(size, maximum));
      }
    } else {
      return;
    }

    if (event.type === "change" && PANEL_FIELDS.includes(name)) {
      this.#save();
    }
  }

  @action
  toggleNavigation() {
    this.navigation = this.navigation === "open" ? "hidden" : "open";
    this.#save();
  }

  @action
  openNavigation() {
    this.navigation = "open";
    this.#save();
  }

  @action
  openContext() {
    this.context = "open";
    this.#save();
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
