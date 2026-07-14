// @ts-check
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";

// Persisted under core's global key-value store; the `wireframe_` prefix
// namespaces our keys within its shared `discourse_` bucket to avoid collisions.
const COLLAPSED_KEY = "wireframe_leftCollapsed";
const PANEL_KEY = "wireframe_leftPanelTab";
const RIGHT_COLLAPSED_KEY = "wireframe_rightCollapsed";
const LEFT_WIDTH_KEY = "wireframe_leftPanelWidth";
const RIGHT_WIDTH_KEY = "wireframe_rightRailWidth";

// The panels the left rail can show. A stale localStorage value (from a removed
// panel) is validated against this set and falls back to the first entry.
const PANELS = ["palette", "outline", "issues"];
const DEFAULT_PANEL = "palette";

// Rail width bounds, in pixels. The LEFT value is the wide panel only — the 48px
// activity bar is fixed and sits beside it, so the left rail's total width is
// this plus the bar. Bounds keep a panel usable (min) without swallowing the
// canvas (max).
const LEFT_MIN = 220;
const LEFT_MAX = 520;
const LEFT_DEFAULT = 320;
const RIGHT_MIN = 240;
const RIGHT_MAX = 520;
const RIGHT_DEFAULT = 300;

// The CSS custom properties the shell grid columns AND the body padding read in
// lockstep (see wireframe-chrome.scss). Driving these is how a rail resizes; the
// grid and canvas inset can't drift because they share the one source.
const LEFT_VAR = "--wf-left-panel";
const RIGHT_VAR = "--wf-right-rail";

/**
 * Owns the editor's rail UI state — which left panel is active, whether each rail
 * is collapsed, and each rail's width — so any part of the editor can read or
 * drive it without a line to the shell component. The activity bar and shell bind
 * their chrome to this service; detached UI (the quick-inserter's "Browse all",
 * which lives in a portal) calls `showPalette()` directly.
 *
 * State invariant: `leftPanelTab` is ALWAYS a real panel (never null) — it names
 * the active panel; `leftCollapsed`/`rightCollapsed` are separate flags for
 * whether each rail's wide body is visible. The left panel/collapse pair is kept
 * in sync by funnelling every mutation through
 * `activatePanel`/`setLeftPanelTab`/`showPalette`, so they can't drift. All of
 * these preferences — active panel, both collapse flags, both widths — are
 * persisted across editor sessions.
 *
 * Widths are applied as inline CSS custom properties on `document.body` (where
 * `body.wireframe-active` scopes them). A collapsed rail must NOT carry an inline
 * width: the stylesheet's collapse rule sets the var to the slim/zero width, and
 * an inline value would override it. So the width and collapse setters funnel
 * through one place that clears the inline var while collapsed and re-applies the
 * persisted width on expand.
 */
export default class WireframeRail extends Service {
  @service keyValueStore;

  /** The active left-rail panel: "palette" | "outline" | "issues". */
  @tracked leftPanelTab;

  @tracked leftCollapsed;

  @tracked rightCollapsed;

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
  /**
   * The left panel and right rail widths, in pixels. Tracked so the resize
   * handles' `aria-valuenow` tracks live; read through the getters below (not
   * directly from a template), so they stay underscore-private.
   */
  @tracked _leftPanelWidth;
  @tracked _rightRailWidth;

  constructor() {
    super(...arguments);
    // Hydrate from persisted prefs in the constructor (not a field initializer)
    // so the injected `keyValueStore` is resolvable. Widths are clamped on read
    // so a value left behind by an old min/max self-corrects.
    this.leftPanelTab = this.#readPanel();
    this.leftCollapsed = this.keyValueStore.getObject(COLLAPSED_KEY) ?? false;
    this.rightCollapsed =
      this.keyValueStore.getObject(RIGHT_COLLAPSED_KEY) ?? false;
    this._leftPanelWidth = this.#clamp(
      this.keyValueStore.getObject(LEFT_WIDTH_KEY) ?? LEFT_DEFAULT,
      LEFT_MIN,
      LEFT_MAX
    );
    this._rightRailWidth = this.#clamp(
      this.keyValueStore.getObject(RIGHT_WIDTH_KEY) ?? RIGHT_DEFAULT,
      RIGHT_MIN,
      RIGHT_MAX
    );
  }

  /** @returns {number} The current left panel width, in pixels. */
  get leftPanelWidth() {
    return this._leftPanelWidth;
  }

  /** @returns {number} The current right rail width, in pixels. */
  get rightRailWidth() {
    return this._rightRailWidth;
  }

  /** @returns {number} */
  get leftPanelMin() {
    return LEFT_MIN;
  }

  /** @returns {number} */
  get leftPanelMax() {
    return LEFT_MAX;
  }

  /** @returns {number} */
  get rightRailMin() {
    return RIGHT_MIN;
  }

  /** @returns {number} */
  get rightRailMax() {
    return RIGHT_MAX;
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
      this.#setLeftCollapsed(true);
    } else {
      this.leftPanelTab = tab;
      this.keyValueStore.setObject({ key: PANEL_KEY, value: tab });
      this.#setLeftCollapsed(false);
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
    this.#setLeftCollapsed(false);
  }

  @action
  toggleLeftCollapsed() {
    this.#setLeftCollapsed(!this.leftCollapsed);
  }

  @action
  toggleRightCollapsed() {
    this.#setRightCollapsed(!this.rightCollapsed);
  }

  /**
   * Reveals the palette: switches to its tab and expands the rail if collapsed.
   */
  @action
  showPalette() {
    this.setLeftPanelTab("palette");
  }

  /**
   * Sets the left panel width (from a drag or a keyboard nudge), clamped. Applies
   * the inline CSS var live so the drag is smooth; persists only when `commit` is
   * true (drag end / keyboard step) to avoid a write per pointermove.
   *
   * @param {number} px
   * @param {{ commit?: boolean }} [options]
   */
  @action
  setLeftPanelWidth(px, { commit = false } = {}) {
    this._leftPanelWidth = this.#clamp(px, LEFT_MIN, LEFT_MAX);
    if (!this.leftCollapsed) {
      this.#applyVar(LEFT_VAR, this._leftPanelWidth);
    }
    if (commit) {
      this.keyValueStore.setObject({
        key: LEFT_WIDTH_KEY,
        value: this._leftPanelWidth,
      });
    }
  }

  /**
   * Sets the right rail width (from a drag or a keyboard nudge), clamped. See
   * {@link setLeftPanelWidth}.
   *
   * @param {number} px
   * @param {{ commit?: boolean }} [options]
   */
  @action
  setRightRailWidth(px, { commit = false } = {}) {
    this._rightRailWidth = this.#clamp(px, RIGHT_MIN, RIGHT_MAX);
    if (!this.rightCollapsed) {
      this.#applyVar(RIGHT_VAR, this._rightRailWidth);
    }
    if (commit) {
      this.keyValueStore.setObject({
        key: RIGHT_WIDTH_KEY,
        value: this._rightRailWidth,
      });
    }
  }

  /**
   * Nudges the left panel width by `delta` px and commits (keyboard resize).
   *
   * @param {number} delta
   */
  @action
  nudgeLeftPanelWidth(delta) {
    this.setLeftPanelWidth(this._leftPanelWidth + delta, { commit: true });
  }

  /**
   * Nudges the right rail width by `delta` px and commits (keyboard resize).
   *
   * @param {number} delta
   */
  @action
  nudgeRightRailWidth(delta) {
    this.setRightRailWidth(this._rightRailWidth + delta, { commit: true });
  }

  /**
   * Applies both rails' current widths to the body vars. Call on shell insert so
   * a persisted width takes effect; a collapsed rail is left to the stylesheet.
   */
  @action
  applyRailWidths() {
    if (this.leftCollapsed) {
      this.#clearVar(LEFT_VAR);
    } else {
      this.#applyVar(LEFT_VAR, this._leftPanelWidth);
    }
    if (this.rightCollapsed) {
      this.#clearVar(RIGHT_VAR);
    } else {
      this.#applyVar(RIGHT_VAR, this._rightRailWidth);
    }
  }

  /**
   * Removes both inline rail-width vars from the body. Call on shell teardown so
   * leaving the editor doesn't leave stray custom properties on `document.body`.
   */
  @action
  clearRailWidths() {
    this.#clearVar(LEFT_VAR);
    this.#clearVar(RIGHT_VAR);
  }

  /**
   * Persists and applies the left collapse flag in one place. A collapsed rail
   * drops its inline width var so the stylesheet's collapse rule wins; expanding
   * re-applies the persisted width.
   *
   * @param {boolean} collapsed
   */
  #setLeftCollapsed(collapsed) {
    this.leftCollapsed = collapsed;
    this.keyValueStore.setObject({ key: COLLAPSED_KEY, value: collapsed });
    if (collapsed) {
      this.#clearVar(LEFT_VAR);
    } else {
      this.#applyVar(LEFT_VAR, this._leftPanelWidth);
    }
  }

  /**
   * Persists and applies the right collapse flag; see {@link #setLeftCollapsed}.
   *
   * @param {boolean} collapsed
   */
  #setRightCollapsed(collapsed) {
    this.rightCollapsed = collapsed;
    this.keyValueStore.setObject({
      key: RIGHT_COLLAPSED_KEY,
      value: collapsed,
    });
    if (collapsed) {
      this.#clearVar(RIGHT_VAR);
    } else {
      this.#applyVar(RIGHT_VAR, this._rightRailWidth);
    }
  }

  /**
   * @param {string} name
   * @param {number} px
   */
  #applyVar(name, px) {
    document.body.style.setProperty(name, `${px}px`);
  }

  /** @param {string} name */
  #clearVar(name) {
    document.body.style.removeProperty(name);
  }

  /**
   * @param {number} value
   * @param {number} min
   * @param {number} max
   * @returns {number}
   */
  #clamp(value, min, max) {
    return Math.min(max, Math.max(min, value));
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
