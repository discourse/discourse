import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { trustHTML } from "@ember/template";
import booleanString from "discourse/helpers/boolean-string";
import type { Side } from "discourse/lib/geometry";
import KeyValueStore from "discourse/lib/key-value-store";
import { eq, or } from "discourse/truth-helpers";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const STORE_NAMESPACE = "d_panel_dock_";
const DEFAULT_WIDTH = 320;
const MIN_WIDTH = 240;
const MAX_WIDTH = 720;
const DEFAULT_HEIGHT = 320;
const MIN_HEIGHT = 160;
const MAX_HEIGHT = 600;

const SIDES = ["start", "end", "bottom"] as const;

/** A viewport edge the panel can dock against. */
export type DockSide = (typeof SIDES)[number];

/** The panel's placement and sizes, as persisted between visits. */
interface DockLayout {
  mode: "docked" | "window";
  side: DockSide;
  width: number;
  height: number;
  window?: {
    width: number;
    height: number;
    left: number;
    top: number;
  };
}

interface PanelDockChassisSignature {
  /** The panel itself; the surrounding layer is not addressable. */
  Element: HTMLDivElement;
  Args: {
    /** Whether the panel is rendered. */
    isOpen?: boolean;

    /**
     * Name under which the panel's layout is remembered across visits.
     * Omitting it makes a resize or dock change last only as long as the panel
     * is rendered.
     */
    storageKey?: string;

    /** Whether the header offers a dock side picker. Defaults to false. */
    dockable?: boolean;

    /** The side used before the user picks one. Defaults to `"start"`. */
    defaultSide?: DockSide;

    /**
     * The width used before the user resizes, in pixels. Defaults to 320. A
     * stored width always wins over it.
     */
    defaultWidth?: number;

    /** Called with the chosen side when the user picks one. */
    onDock?: (side: DockSide) => void;

    /**
     * Called with the new size along the active axis, in pixels, once a
     * resize finishes.
     */
    onResize?: (size: number) => void;
  };
  Blocks: {
    /** The panel's header row. Omitting it leaves the panel headerless. */
    header: [];

    /**
     * Controls rendered at the end of the header row, after the dock picker,
     * so that a caller's close button stays last.
     */
    actions: [];

    /** The panel's content. */
    body: [];
  };
}

/**
 * A panel docked to an edge of the viewport that stays open while the page
 * behind it is used.
 *
 * It is deliberately not a modal: the page underneath keeps receiving clicks,
 * nothing is focus trapped, and scrolling is not locked. That is what makes it
 * suitable for content you consult *while* working, rather than content you
 * deal with and dismiss. For the latter, use `DModal`.
 *
 * The panel does not set a `z-index`. Where it belongs in the stacking order
 * depends on what it is being used for, so the caller styles that; the panel
 * only establishes the layer that lets clicks through.
 *
 * ```hbs
 * <PanelDockChassis @isOpen={{this.isOpen}} @storageKey="my-feature" @dockable={{true}}>
 *   <:header>Title</:header>
 *   <:actions><button type="button">Close</button></:actions>
 *   <:body>Content</:body>
 * </PanelDockChassis>
 * ```
 */
export default class PanelDockChassis extends Component<PanelDockChassisSignature> {
  #store = new KeyValueStore(STORE_NAMESPACE);
  @tracked _side: DockSide;
  @tracked _width: number;
  @tracked _height: number;

  constructor(owner: Owner, args: PanelDockChassisSignature["Args"]) {
    super(owner, args);

    // Read once at construction rather than in getters. The stored layout is
    // only a starting point, and re-reading it on every render would undo a
    // resize that has not been committed yet.
    const layout = this.#restoreLayout();
    this._side = layout.side;
    this._width = layout.width;
    this._height = layout.height;
  }

  get side() {
    return this._side;
  }

  get isBottom() {
    return this._side === "bottom";
  }

  /**
   * The current width, clamped to the range the panel can be dragged to.
   *
   * @returns A width in pixels.
   */
  get width() {
    return Math.min(Math.max(this._width, MIN_WIDTH), this.maxWidth);
  }

  /**
   * The largest width the panel may take, given the space available.
   *
   * The viewport term lives here rather than in the stylesheet so that the
   * width reported through `aria-valuenow` and `@onResize` is the width that
   * actually renders. A `90vw` cap applied only in CSS would silently diverge
   * from both on a narrow viewport.
   *
   * @returns A width in pixels.
   */
  get maxWidth() {
    return Math.min(MAX_WIDTH, Math.round(window.innerWidth * 0.9));
  }

  /** The current height, clamped like the width. */
  get height() {
    return Math.min(Math.max(this._height, MIN_HEIGHT), this.maxHeight);
  }

  get maxHeight() {
    return Math.min(MAX_HEIGHT, Math.round(window.innerHeight * 0.8));
  }

  /** The size along the axis the active dock side resizes on. */
  get size() {
    return this.isBottom ? this.height : this.width;
  }

  get minSize() {
    return this.isBottom ? MIN_HEIGHT : MIN_WIDTH;
  }

  get maxSize() {
    return this.isBottom ? this.maxHeight : this.maxWidth;
  }

  /**
   * The separator's `@side` — the anchored edge along the active axis, which
   * is the dock side itself. It collapses to two values because a bottom dock
   * anchors at its block-end edge, so only a start dock resolves to `"start"`.
   */
  get anchoredSide(): Side {
    return this._side === "start" ? "start" : "end";
  }

  /**
   * The sizes, as custom properties for the stylesheet to consume.
   *
   * Custom properties rather than inline dimensions keep the sizing rules in
   * the stylesheet, where the dock side modifier decides which one applies.
   *
   * @returns A style attribute value.
   */
  get style() {
    return trustHTML(
      `--d-panel-dock-width: ${this.width}px; --d-panel-dock-height: ${this.height}px;`
    );
  }

  /**
   * Updates the rendered size along the active axis without storing it.
   *
   * @param size - The size to render, in pixels.
   */
  @action
  previewSize(size: number) {
    if (this.isBottom) {
      this._height = size;
    } else {
      this._width = size;
    }
  }

  /**
   * Stores the size the panel was left at.
   *
   * @param size - The size to store, in pixels.
   */
  @action
  commitSize(size: number) {
    this.previewSize(size);
    this.#persist();
    this.args.onResize?.(size);
  }

  /**
   * Docks the panel against the given side.
   *
   * @param side - The side to dock against.
   */
  @action
  setSide(side: DockSide) {
    this._side = side;
    this.#persist();
    this.args.onDock?.(side);
  }

  @action
  isSide(side: DockSide) {
    return this._side === side;
  }

  #persist() {
    if (!this.args.storageKey) {
      return;
    }

    this.#store.setObject({
      key: this.args.storageKey,
      value: {
        mode: "docked",
        side: this.side,
        width: this.width,
        height: this.height,
      } satisfies DockLayout,
    });
  }

  /**
   * Reads the layout this panel was last left at.
   *
   * Anything stored that is not a recognizable layout object is ignored and
   * the defaults apply.
   *
   * @returns The stored layout, or the defaults when there is none.
   */
  #restoreLayout(): DockLayout {
    const fallback: DockLayout = {
      mode: "docked",
      side: this.args.defaultSide ?? "start",
      width: this.args.defaultWidth ?? DEFAULT_WIDTH,
      height: DEFAULT_HEIGHT,
    };

    if (!this.args.storageKey) {
      return fallback;
    }

    const stored = this.#store.getObject(this.args.storageKey) as
      | {
          side?: unknown;
          width?: unknown;
          height?: unknown;
          mode?: unknown;
          window?: unknown;
        }
      | number
      | undefined;

    if (
      typeof stored === "object" &&
      stored !== null &&
      SIDES.includes(stored.side as DockSide) &&
      typeof stored.width === "number" &&
      typeof stored.height === "number"
    ) {
      return {
        mode: "docked",
        side: stored.side as DockSide,
        width: stored.width,
        height: stored.height,
      };
    }

    return fallback;
  }

  <template>
    {{#if @isOpen}}
      {{! The layer spans the viewport so the panel can be positioned against
          its edges, but lets pointer events through so the page underneath
          stays usable. The panel itself takes them back. }}
      <div class="d-panel-dock-layer">
        <div
          class={{dConcatClass "d-panel-dock" (concat "--dock-" this.side)}}
          style={{this.style}}
          ...attributes
        >
          {{! The header row also hosts the dock picker and the caller's
              actions, so it must render whenever any of the three exist —
              otherwise a headerless dockable panel would silently lose its
              controls. }}
          {{#if (or (has-block "header") @dockable (has-block "actions"))}}
            <div class="d-panel-dock__header">
              {{yield to="header"}}

              <div class="d-panel-dock__actions">
                {{#if @dockable}}
                  <div
                    class="d-panel-dock__dock-picker"
                    role="group"
                    aria-label={{i18n "panel_dock.dock"}}
                  >
                    {{#each SIDES as |side|}}
                      <button
                        type="button"
                        class={{dConcatClass
                          "d-panel-dock__dock-button"
                          (concat "--" side)
                        }}
                        aria-pressed={{booleanString
                          (this.isSide side)
                          omitFalse=false
                        }}
                        aria-label={{i18n (concat "panel_dock.dock_" side)}}
                        title={{i18n (concat "panel_dock.dock_" side)}}
                        {{on "click" (fn this.setSide side)}}
                      >
                        <svg
                          width="16"
                          height="16"
                          viewBox="0 0 16 16"
                          aria-hidden="true"
                        >
                          <rect
                            x="1.5"
                            y="2.5"
                            width="13"
                            height="11"
                            rx="1.5"
                            stroke="currentColor"
                            fill="none"
                            stroke-width="1.5"
                          />
                          {{#if (eq side "start")}}
                            <rect
                              x="3"
                              y="4"
                              width="4"
                              height="8"
                              rx="0.5"
                              fill="currentColor"
                            />
                          {{else if (eq side "end")}}
                            <rect
                              x="9"
                              y="4"
                              width="4"
                              height="8"
                              rx="0.5"
                              fill="currentColor"
                            />
                          {{else}}
                            <rect
                              x="3"
                              y="8"
                              width="10"
                              height="4"
                              rx="0.5"
                              fill="currentColor"
                            />
                          {{/if}}
                        </svg>
                      </button>
                    {{/each}}
                  </div>
                {{/if}}

                {{yield to="actions"}}
              </div>
            </div>
          {{/if}}

          <div class="d-panel-dock__body">
            {{yield to="body"}}
          </div>

          <DResizeSeparator
            class="d-panel-dock__resizer"
            @axis={{if this.isBottom "vertical" "horizontal"}}
            @side={{this.anchoredSide}}
            @value={{this.size}}
            @min={{this.minSize}}
            @max={{this.maxSize}}
            @label={{i18n "panel_dock.resize"}}
            @onResize={{this.previewSize}}
            @onResizeEnd={{this.commitSize}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
