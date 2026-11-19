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
const PANEL_KEY = "wireframe_leftPanelTab";
const RIGHT_COLLAPSED_KEY = "wireframe_rightCollapsed";
const LEFT_WIDTH_KEY = "wireframe_leftPanelWidth";
const RIGHT_WIDTH_KEY = "wireframe_rightRailWidth";

// The sections the left panel can show. A stale localStorage value (from a
// removed section) is validated against this set and falls back to the first.
const PANELS = ["palette", "outline", "issues"] as const;
/** A section selectable in the editor's left panel. */
export type WireframeRailPanel = (typeof PANELS)[number];
const DEFAULT_PANEL: WireframeRailPanel = "palette";

// Rail width bounds, in pixels. The left minimum is set by its header, which
// has to fit the three labelled section segments; the maxima keep a rail from
// swallowing the canvas.
const LEFT_MIN = 240;
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
 * Owns the editor's rail UI state — which left section is active, whether the
 * right rail is collapsed, and each rail's width — so any part of the editor
 * can read or drive it without a line to the shell component. The panel
 * switcher and shell bind their chrome to this service; detached UI (the
 * quick-inserter's "Browse all", which lives in a portal) calls `showPalette()`
 * directly.
 *
 * State invariant: `leftPanelTab` is ALWAYS a real section (never null). The
 * left panel is always open; only the right rail collapses. All of these
 * preferences — active section, the right collapse flag, both widths — are
 * persisted across editor sessions.
 *
 * Widths are applied as inline CSS custom properties on `document.body` (where
 * `body.wireframe-active` scopes them). A collapsed rail must NOT carry an inline
 * width: the stylesheet's collapse rule sets the var to the slim width, and an
 * inline value would override it. So the right width and collapse setters funnel
 * through one place that clears the inline var while collapsed and re-applies the
 * persisted width on expand.
 */
export default class WireframeRail extends Service {
  /** Persists rail preferences in core's global namespaced store. */
  @service declare keyValueStore: ProxiedKeyValueStoreService;

  /** The active left section: "palette" | "outline" | "issues". */
  @tracked declare leftPanelTab: WireframeRailPanel;

  /** Whether the right inspector rail is collapsed. */
  @tracked declare rightCollapsed: boolean;

  @tracked inspectorTab = "args";

  /** Field to focus after the inspector has rendered. */
  @tracked
  inspectorField: {
    /** Block whose argument should be revealed. */
    blockKey: string;
    /** Argument field to focus. */
    argName: string;
    /** Source controls to reveal for image arguments; defaults to light. */
    imageVariant?: "light" | "dark";
  } | null = null;

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
   * Sets the active left section and persists it.
   *
   * @param tab - Section that should be shown.
   */
  @action
  setLeftPanelTab(tab: WireframeRailPanel): void {
    this.leftPanelTab = tab;
    this.keyValueStore.setObject({ key: PANEL_KEY, value: tab });
  }

  /** Toggles whether the right inspector rail is collapsed. */
  @action
  toggleRightCollapsed(): void {
    this.#setRightCollapsed(!this.rightCollapsed);
  }

  /** Opens Args, optionally revealing a specific field on the selected block. */
  showInspector(field: WireframeRail["inspectorField"] = null): void {
    this.inspectorTab = "args";
    this.inspectorField = field;
    this.#setRightCollapsed(false);
  }

  /** Reveals the palette section. */
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
    this.#applyVar(LEFT_VAR, this._leftPanelWidth);
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
    this.#applyVar(LEFT_VAR, this._leftPanelWidth);
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
   * Persists and applies the right collapse flag in one place. A collapsed rail
   * drops its inline width var so the stylesheet's collapse rule wins; expanding
   * re-applies the persisted width.
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
   * Reads the persisted active section, validating against the known set so a
   * value left behind by a removed section can't select one that no longer
   * exists.
   *
   * @returns Persisted section when valid, otherwise the default.
   */
  #readPanel(): WireframeRailPanel {
    const stored = this.keyValueStore.getObject(PANEL_KEY);
    return this.#isPanel(stored) ? stored : DEFAULT_PANEL;
  }

  /**
   * Narrows a persisted value to one of the supported section identifiers.
   *
   * @param value - Parsed value read from the key-value store.
   */
  #isPanel(value: unknown): value is WireframeRailPanel {
    return PANELS.some((panel) => panel === value);
  }
}
