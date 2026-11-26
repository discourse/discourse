import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import Service, { service } from "@ember/service";
import ContextAbout from "discourse/components/page-shell/context-about";
import ContextCategory from "discourse/components/page-shell/context-category";
import ContextTopic from "discourse/components/page-shell/context-topic";
import discourseDebounce from "discourse/lib/debounce";
import EmbedMode from "discourse/lib/embed-mode";
import { applyValueTransformer } from "discourse/lib/transformer";

/**
 * @typedef {object} ContextView
 * @property {string} id
 * @property {string} label Translation key for the picker option.
 * @property {import("@glint/template").ComponentLike} component
 * @property {boolean} [preferred] Selects the view when the tab has no saved choice.
 */

/** @type {ContextView} */
const ABOUT_CONTEXT_VIEW = {
  id: "about",
  label: "about.simple_title",
  component: ContextAbout,
};

/** @type {ContextView} */
const TOPIC_CONTEXT_VIEW = {
  id: "topic",
  label: "page_shell.context_topic",
  component: ContextTopic,
};

/** @type {ContextView} */
const CATEGORY_CONTEXT_VIEW = {
  id: "category-guide",
  label: "page_shell.context_category",
  component: ContextCategory,
};

const STORAGE_KEY = "page-shell-panels";
const STORAGE_VERSION = 1;
const LEGACY_HIDDEN_KEY = "sidebar-hidden";
const PANEL_MODES = {
  navigation: ["open", "rail"],
  context: ["open", "hidden"],
};
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
  const storedMode =
    name === "navigation" && stored?.mode === "hidden" ? "rail" : stored?.mode;
  const mode = PANEL_MODES[name].includes(storedMode)
    ? storedMode
    : fallbackMode;
  const width =
    typeof stored?.width === "number" && Number.isFinite(stored.width)
      ? Math.round(Math.max(minWidth, Math.min(stored.width, maxWidth)))
      : defaultWidth;
  return { mode, width };
}

export default class PageShell extends Service {
  @service currentUser;
  @service discovery;
  @service header;
  @service keyValueStore;
  @service router;
  @service sessionStore;
  @service siteSettings;

  @tracked width = "full";
  @tracked resize = "content";
  @tracked navigation;
  @tracked context;
  @tracked contextPosition = "start";
  @tracked footer = "content";
  @tracked navigationWidth;
  @tracked contextWidth;
  @tracked navigationMaxWidth = PANEL_LIMITS.navigation.maxWidth;
  @tracked contextMaxWidth = Math.max(200, Math.min(1000, window.innerWidth));
  @tracked compactLogo = false;
  @tracked contextFits = false;
  @tracked closingContext = false;
  @tracked animatingPanels = false;

  #animationTimer;
  #selectedContextViewId = tracked(null);

  constructor() {
    super(...arguments);
    this.#load();
    this.#selectedContextViewId.value = this.sessionStore.getItem(
      this.#contextViewStorageKey
    );
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

  get isFullPage() {
    return this.router.currentRoute?.metadata?.fullPage === true;
  }

  get enabled() {
    return (
      this.siteSettings.enable_page_shell_prototype &&
      this.siteSettings.enable_main_outlet_grid_layout_change &&
      !EmbedMode.enabled &&
      !this.isFullPage
    );
  }

  get hasContextPanel() {
    return !this.router.currentRouteName?.includes("preferences");
  }

  get canOpenContext() {
    return this.enabled && this.hasContextPanel && this.contextFits;
  }

  get contextCategory() {
    const topic = this.header.topicInfo;
    return (
      this.discovery.category ??
      (topic?.isPrivateMessage ? null : topic?.category)
    );
  }

  /** @returns {ContextView[]} */
  @cached
  get contextViews() {
    const views = [ABOUT_CONTEXT_VIEW];
    if (this.canOpenContext && this.header.topicInfo) {
      views.push(TOPIC_CONTEXT_VIEW);
    }

    if (this.canOpenContext && this.contextCategory) {
      views.push(CATEGORY_CONTEXT_VIEW);
    }

    return [...views, ...applyValueTransformer("page-shell-context-view", [])];
  }

  get selectedContextView() {
    const selectedId = this.#selectedContextViewId.value;
    return (
      (selectedId
        ? this.contextViews.find((view) => view.id === selectedId)
        : this.contextViews.find((view) => view.preferred)) ??
      ABOUT_CONTEXT_VIEW
    );
  }

  get #contextViewStorageKey() {
    return `page-shell-context-view:${this.currentUser?.id ?? "anonymous"}`;
  }

  @action
  selectContextView(id) {
    this.#selectedContextViewId.value = id;
    this.sessionStore.setItem(this.#contextViewStorageKey, id);
  }

  openContext() {
    if (!this.canOpenContext) {
      return false;
    }

    this.#setPanelMode("context", "open");
    this.#save();
    return true;
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
      contextPosition: ["start", "end"],
      footer: ["content", "row", "off"],
    };

    if (name === "navigation" || name === "context") {
      if (!PANEL_MODES[name].includes(value)) {
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
      this.navigation === "open" ? "rail" : "open"
    );
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
      if (panel === "context") {
        this.closingContext = mode === "hidden";
      }
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
    this.closingContext = false;
  }

  #load() {
    let stored = this.keyValueStore.getObject(STORAGE_KEY);
    if (stored?.version !== STORAGE_VERSION) {
      stored = null;
    }
    // Without a saved shell preference, start from the legacy sidebar choice.
    const navigationFallback =
      !stored && this.keyValueStore.getItem(LEGACY_HIDDEN_KEY)
        ? "rail"
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
    if (this.navigation === "rail") {
      this.keyValueStore.setItem(LEGACY_HIDDEN_KEY, "true");
    } else {
      this.keyValueStore.removeItem(LEGACY_HIDDEN_KEY);
    }
  }
}
