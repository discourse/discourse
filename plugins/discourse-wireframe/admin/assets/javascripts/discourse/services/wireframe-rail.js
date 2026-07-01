// @ts-check
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";

// Persisted under core's global key-value store; the `wireframe_` prefix
// namespaces our keys within its shared `discourse_` bucket to avoid collisions.
const COLLAPSED_KEY = "wireframe_leftCollapsed";
const PANEL_KEY = "wireframe_leftPanelTab";

// The panels the left rail can show. A stale localStorage value (from a removed
// panel) is validated against this set and falls back to the first entry.
const PANELS = ["palette", "outline", "issues"];
const DEFAULT_PANEL = "palette";

/**
 * Owns the editor's left-rail UI state — which panel is active and whether the
 * rail's wide panel is collapsed — so any part of the editor can read or drive
 * it without a line to the shell component. The activity bar and shell bind
 * their chrome to this service; detached UI (the quick-inserter's "Browse all",
 * which lives in a portal) calls `showPalette()` directly.
 *
 * State invariant: `leftPanelTab` is ALWAYS a real panel (never null) — it names
 * the active panel; `leftCollapsed` is a separate flag for whether that panel's
 * wide body is visible. The two are kept in sync by funnelling every mutation
 * through `activatePanel`/`setLeftPanelTab`/`showPalette`, so they can't drift
 * (e.g. an "active" entry whose panel is actually a different one). Both
 * preferences are persisted across editor sessions.
 */
export default class WireframeRail extends Service {
  @service keyValueStore;

  /** The active left-rail panel: "palette" | "outline" | "issues". */
  @tracked leftPanelTab;

  @tracked leftCollapsed;

  /**
   * Whether `tab` is the active panel, regardless of collapse — drives the body
   * switch (which panel component to render once the wide panel is open).
   *
   * @param {string} tab
   * @returns {boolean}
   */
  isLeftPanelTabActive = (tab) => this.leftPanelTab === tab;

  /**
   * Whether `tab`'s panel is currently OPEN — active and not collapsed. Drives
   * the activity bar's pressed/selected state: a collapsed rail has no open
   * panel, so every entry reads as not-pressed.
   *
   * @param {string} tab
   * @returns {boolean}
   */
  isPanelOpen = (tab) => this.leftPanelTab === tab && !this.leftCollapsed;

  constructor() {
    super(...arguments);
    // Hydrate from persisted prefs in the constructor (not a field initializer)
    // so the injected `keyValueStore` is resolvable.
    this.leftPanelTab = this.#readPanel();
    this.leftCollapsed = this.keyValueStore.getObject(COLLAPSED_KEY) ?? false;
  }

  /**
   * Activity-bar toggle. Clicking the already-open panel's entry collapses the
   * wide panel (the icon rail persists); clicking any other entry switches to it
   * and expands. This is the VS Code activity-bar interaction.
   *
   * @param {string} tab
   */
  @action
  activatePanel(tab) {
    if (this.isPanelOpen(tab)) {
      this.#setCollapsed(true);
    } else {
      this.leftPanelTab = tab;
      this.keyValueStore.setObject({ key: PANEL_KEY, value: tab });
      this.#setCollapsed(false);
    }
  }

  /**
   * Sets the active panel and ensures the wide panel is expanded. Kept as a
   * distinct entry point (vs the `activatePanel` toggle) for callers that want
   * "show this panel" semantics without the click-to-collapse behavior.
   *
   * @param {string} tab
   */
  @action
  setLeftPanelTab(tab) {
    this.leftPanelTab = tab;
    this.keyValueStore.setObject({ key: PANEL_KEY, value: tab });
    this.#setCollapsed(false);
  }

  @action
  toggleLeftCollapsed() {
    this.#setCollapsed(!this.leftCollapsed);
  }

  /**
   * Reveals the palette: switches to its tab and expands the rail if collapsed.
   */
  @action
  showPalette() {
    this.setLeftPanelTab("palette");
  }

  /**
   * Persists and applies the collapse flag in one place so every mutation path
   * writes storage consistently.
   *
   * @param {boolean} collapsed
   */
  #setCollapsed(collapsed) {
    this.leftCollapsed = collapsed;
    this.keyValueStore.setObject({ key: COLLAPSED_KEY, value: collapsed });
  }

  /**
   * Reads the persisted active panel, validating against the known set so a
   * value left behind by a removed panel can't select a panel that no longer
   * exists.
   *
   * @returns {string}
   */
  #readPanel() {
    const stored = this.keyValueStore.getObject(PANEL_KEY);
    return PANELS.includes(stored) ? stored : DEFAULT_PANEL;
  }
}
