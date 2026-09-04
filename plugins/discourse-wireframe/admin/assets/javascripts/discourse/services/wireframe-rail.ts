import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import Service, { service } from "@ember/service";
import type KeyValueStoreService from "discourse/services/key-value-store";

// TODO(devxp-typescript-pending): use the core service type directly once it
// declares the `KeyValueStore` methods installed dynamically by its proxy loop.
interface ProxiedKeyValueStoreService extends KeyValueStoreService {
  /** Reads and parses a value stored under the supplied key. */
  getObject<Value = unknown>(
    /** Key within the service's global namespace. */
    key: string
  ): Value | null | undefined;
  /** Serializes and stores a value under the supplied key. */
  setObject<Value>(
    /** Storage key and JSON-serializable value to persist. */
    options: {
      /** Key within the service's global namespace. */
      key: string;
      /** JSON-serializable value written for the key. */
      value: Value;
    }
  ): void;
}

// Persisted under core's global key-value store; the `wireframe_` prefix
// namespaces our keys within its shared `discourse_` bucket to avoid collisions.
const COLLAPSED_KEY = "wireframe_leftCollapsed";
const PANEL_KEY = "wireframe_leftPanelTab";
const RIGHT_COLLAPSED_KEY = "wireframe_rightCollapsed";
const LEFT_WIDTH_KEY = "wireframe_leftPanelWidth";
const RIGHT_WIDTH_KEY = "wireframe_rightRailWidth";

// The panels the left rail can show. A stale localStorage value (from a removed
// panel) is validated against this set and falls back to the first entry.
const PANELS = ["palette", "outline", "issues"] as const;
/** A panel selectable from the editor's left activity rail. */
export type WireframeRailPanel = (typeof PANELS)[number];
const DEFAULT_PANEL: WireframeRailPanel = "palette";

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
  /** Persists rail preferences in core's global namespaced store. */
  @service declare keyValueStore: ProxiedKeyValueStoreService;

  /** The active left-rail panel: "palette" | "outline" | "issues". */
  @tracked declare leftPanelTab: WireframeRailPanel;

  /** Whether the left panel body is collapsed. */
  @tracked declare leftCollapsed: boolean;

  /** Whether the right inspector rail is collapsed. */
  @tracked declare rightCollapsed: boolean;

  /**
   * Whether `tab` is the active panel, regardless of collapse — drives the body
   * switch (which panel component to render once the wide panel is open).
   *
   * @param tab - Left-rail panel to compare with the active panel.
   */
  isLeftPanelTabActive = (tab: WireframeRailPanel): boolean =>
    this.leftPanelTab === tab;
  /**
   * Whether `tab`'s panel is currently OPEN — active and not collapsed. Drives
   * the activity bar's pressed/selected state: a collapsed rail has no open
   * panel, so every entry reads as not-pressed.
   *
   * @param tab - Left-rail panel whose visible state should be checked.
   */
  isPanelOpen = (tab: WireframeRailPanel): boolean =>
    this.leftPanelTab === tab && !this.leftCollapsed;
  /** Internal left panel width in pixels, exposed through `leftPanelWidth`. */
  @tracked declare _leftPanelWidth: number;
  /** Internal right rail width in pixels, exposed through `rightRailWidth`. */
  @tracked declare _rightRailWidth: number;

  /**
   * Creates the service and restores the persisted rail preferences.
   *
   * @param owner - Ember owner used to initialize the service.
   */
  constructor(owner: Owner) {
    super(owner);
    // Hydrate from persisted prefs in the constructor (not a field initializer)
    // so the injected `keyValueStore` is resolvable. Widths are clamped on read
    // so a value left behind by an old min/max self-corrects.
    this.leftPanelTab = this.#readPanel();
    this.leftCollapsed =
      this.keyValueStore.getObject<boolean>(COLLAPSED_KEY) ?? false;
    this.rightCollapsed =
      this.keyValueStore.getObject<boolean>(RIGHT_COLLAPSED_KEY) ?? false;
    this._leftPanelWidth = this.#clamp(
      this.keyValueStore.getObject<number>(LEFT_WIDTH_KEY) ?? LEFT_DEFAULT,
      LEFT_MIN,
      LEFT_MAX
    );
    this._rightRailWidth = this.#clamp(
      this.keyValueStore.getObject<number>(RIGHT_WIDTH_KEY) ?? RIGHT_DEFAULT,
      RIGHT_MIN,
      RIGHT_MAX
    );
  }

  /** The current left panel width, in pixels. */
  get leftPanelWidth(): number {
    return this._leftPanelWidth;
  }

  /** The current right rail width, in pixels. */
  get rightRailWidth(): number {
    return this._rightRailWidth;
  }

  /** Minimum supported left panel width, in pixels. */
  get leftPanelMin(): number {
    return LEFT_MIN;
  }

  /** Maximum supported left panel width, in pixels. */
  get leftPanelMax(): number {
    return LEFT_MAX;
  }

  /** Minimum supported right rail width, in pixels. */
  get rightRailMin(): number {
    return RIGHT_MIN;
  }

  /** Maximum supported right rail width, in pixels. */
  get rightRailMax(): number {
    return RIGHT_MAX;
  }

  /**
   * Activity-bar toggle. Clicking the already-open panel's entry collapses the
   * wide panel (the icon rail persists); clicking any other entry switches to it
   * and expands. This is the VS Code activity-bar interaction.
   *
   * @param tab - Panel selected from the activity bar.
   */
  @action
  activatePanel(tab: WireframeRailPanel): void {
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
   * @param tab - Panel that should be shown and expanded.
   */
  @action
  setLeftPanelTab(tab: WireframeRailPanel): void {
    this.leftPanelTab = tab;
    this.keyValueStore.setObject({ key: PANEL_KEY, value: tab });
    this.#setLeftCollapsed(false);
  }

  /** Toggles whether the left panel body is collapsed. */
  @action
  toggleLeftCollapsed(): void {
    this.#setLeftCollapsed(!this.leftCollapsed);
  }

  /** Toggles whether the right inspector rail is collapsed. */
  @action
  toggleRightCollapsed(): void {
    this.#setRightCollapsed(!this.rightCollapsed);
  }

  /**
   * Reveals the palette: switches to its tab and expands the rail if collapsed.
   */
  @action
  showPalette(): void {
    this.setLeftPanelTab("palette");
  }

  /**
   * Sets the left panel width (from a drag or a keyboard nudge), clamped. Applies
   * the inline CSS var live so the drag is smooth; persists only when `commit` is
   * true (drag end / keyboard step) to avoid a write per pointermove.
   *
   * @param px - Requested panel width in pixels.
   * @param options - Controls whether the updated width is persisted.
   */
  @action
  setLeftPanelWidth(
    px: number,
    {
      commit = false,
    }: {
      /** Whether to persist the updated width. */
      commit?: boolean;
    } = {}
  ): void {
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
   * @param px - Requested rail width in pixels.
   * @param options - Controls whether the updated width is persisted.
   */
  @action
  setRightRailWidth(
    px: number,
    {
      commit = false,
    }: {
      /** Whether to persist the updated width. */
      commit?: boolean;
    } = {}
  ): void {
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
   * @param delta - Signed width change in pixels.
   */
  @action
  nudgeLeftPanelWidth(delta: number): void {
    this.setLeftPanelWidth(this._leftPanelWidth + delta, { commit: true });
  }

  /**
   * Nudges the right rail width by `delta` px and commits (keyboard resize).
   *
   * @param delta - Signed width change in pixels.
   */
  @action
  nudgeRightRailWidth(delta: number): void {
    this.setRightRailWidth(this._rightRailWidth + delta, { commit: true });
  }

  /**
   * Applies both rails' current widths to the body vars. Call on shell insert so
   * a persisted width takes effect; a collapsed rail is left to the stylesheet.
   */
  @action
  applyRailWidths(): void {
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
  clearRailWidths(): void {
    this.#clearVar(LEFT_VAR);
    this.#clearVar(RIGHT_VAR);
  }

  /**
   * Persists and applies the left collapse flag in one place. A collapsed rail
   * drops its inline width var so the stylesheet's collapse rule wins; expanding
   * re-applies the persisted width.
   *
   * @param collapsed - Whether the left panel should be collapsed.
   */
  #setLeftCollapsed(collapsed: boolean): void {
    this.leftCollapsed = collapsed;
    this.keyValueStore.setObject({ key: COLLAPSED_KEY, value: collapsed });
    if (collapsed) {
      this.#clearVar(LEFT_VAR);
    } else {
      this.#applyVar(LEFT_VAR, this._leftPanelWidth);
    }
  }

  /**
   * Persists and applies the right collapse flag; see `#setLeftCollapsed`.
   *
   * @param collapsed - Whether the right rail should be collapsed.
   */
  #setRightCollapsed(collapsed: boolean): void {
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
   * Applies one body-level rail-width custom property.
   *
   * @param name - CSS custom property name.
   * @param px - Width written in pixels.
   */
  #applyVar(name: string, px: number): void {
    document.body.style.setProperty(name, `${px}px`);
  }

  /**
   * Removes one body-level rail-width custom property.
   *
   * @param name - CSS custom property name.
   */
  #clearVar(name: string): void {
    document.body.style.removeProperty(name);
  }

  /**
   * Clamps a rail width to its supported bounds.
   *
   * @param value - Requested width.
   * @param min - Minimum supported width.
   * @param max - Maximum supported width.
   * @returns Clamped width.
   */
  #clamp(value: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, value));
  }

  /**
   * Reads the persisted active panel, validating against the known set so a
   * value left behind by a removed panel can't select a panel that no longer
   * exists.
   *
   * @returns Persisted panel when valid, otherwise the default panel.
   */
  #readPanel(): WireframeRailPanel {
    const stored = this.keyValueStore.getObject(PANEL_KEY);
    return this.#isPanel(stored) ? stored : DEFAULT_PANEL;
  }

  /**
   * Narrows a persisted value to one of the supported panel identifiers.
   *
   * @param value - Parsed value read from the key-value store.
   */
  #isPanel(value: unknown): value is WireframeRailPanel {
    return PANELS.some((panel) => panel === value);
  }
}
