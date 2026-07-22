import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import KeyValueStore from "discourse/lib/key-value-store";
import dResizeEdge from "discourse/ui-kit/modifiers/d-resize-edge";
import { i18n } from "discourse-i18n";

const STORE_NAMESPACE = "d_dock_panel_";
const DEFAULT_WIDTH = 320;
const MIN_WIDTH = 240;
const MAX_WIDTH = 720;

/**
 * A panel docked to the side of the viewport that stays open while the page
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
 * <DDockPanel @isOpen={{this.isOpen}} @storageKey="my-feature">
 *   <:header>Title</:header>
 *   <:body>Content</:body>
 * </DDockPanel>
 * ```
 */
export default class DDockPanel extends Component {
  #store = new KeyValueStore(STORE_NAMESPACE);
  /**
   * The width in pixels, once the panel has been resized in this session.
   *
   * Null until then, so that the getter can fall back to the stored width.
   */
  @tracked _width = null;

  constructor() {
    super(...arguments);

    // Read once at construction rather than in the getter. The stored width is
    // only a starting point, and re-reading it on every render would undo a
    // resize that has not been committed yet.
    this._width = this.#restoreWidth();
  }

  /**
   * The current width, clamped to the range the panel can be dragged to.
   *
   * @returns {number} A width in pixels.
   */
  get width() {
    return Math.min(Math.max(this._width, MIN_WIDTH), this.maxWidth);
  }

  get minWidth() {
    return MIN_WIDTH;
  }

  /**
   * The largest width the panel may take, given the space available.
   *
   * The viewport term lives here rather than in the stylesheet so that the
   * width reported through `aria-valuenow` and `@onResize` is the width that
   * actually renders. A `90vw` cap applied only in CSS would silently diverge
   * from both on a narrow viewport.
   *
   * @returns {number} A width in pixels.
   */
  get maxWidth() {
    return Math.min(MAX_WIDTH, Math.round(window.innerWidth * 0.9));
  }

  /**
   * The width, as a custom property for the stylesheet to consume.
   *
   * A custom property rather than an inline `width` keeps the sizing rules in
   * the stylesheet, where they can be clamped and overridden by media queries.
   *
   * @returns {ReturnType<typeof trustHTML>} A style attribute value.
   */
  get style() {
    return trustHTML(`--d-dock-panel-width: ${this.width}px;`);
  }

  /**
   * Updates the rendered width without storing it.
   *
   * @param {number} width - The width to render, in pixels.
   */
  @action
  previewWidth(width) {
    this._width = width;
  }

  /**
   * Stores the width the panel was left at.
   *
   * @param {number} width - The width to store, in pixels.
   */
  @action
  commitWidth(width) {
    this._width = width;

    if (this.args.storageKey) {
      this.#store.setObject({ key: this.args.storageKey, value: width });
    }

    this.args.onResize?.(width);
  }

  /**
   * Reads the width this panel was last left at.
   *
   * @returns {number} The stored width, or the default when there is none.
   */
  #restoreWidth() {
    if (!this.args.storageKey) {
      return DEFAULT_WIDTH;
    }

    return this.#store.getObject(this.args.storageKey) ?? DEFAULT_WIDTH;
  }

  <template>
    {{#if @isOpen}}
      {{! The layer spans the viewport so the panel can be positioned against
          its edges, but lets pointer events through so the page underneath
          stays usable. The panel itself takes them back. }}
      <div class="d-dock-panel-layer">
        <div class="d-dock-panel" style={{this.style}} ...attributes>
          {{#if (has-block "header")}}
            <div class="d-dock-panel__header">
              {{yield to="header"}}
            </div>
          {{/if}}

          <div class="d-dock-panel__body">
            {{yield to="body"}}
          </div>

          <div
            class="d-dock-panel__resizer"
            role="separator"
            aria-orientation="vertical"
            aria-label={{i18n "dock_panel.resize"}}
            aria-valuenow={{this.width}}
            aria-valuemin={{this.minWidth}}
            aria-valuemax={{this.maxWidth}}
            tabindex="0"
            {{dResizeEdge
              value=this.width
              min=this.minWidth
              max=this.maxWidth
              side="start"
              onResize=this.previewWidth
              onResizeEnd=this.commitWidth
            }}
          ></div>
        </div>
      </div>
    {{/if}}
  </template>
}
