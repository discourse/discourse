// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import EditorBlockPickerMenu from "./editor-block-picker-menu";

/**
 * Unified empty-state placeholder shown wherever the editor needs an
 * "insert a block here" affordance: an empty outlet, an empty non-grid
 * container, an unfilled `wf:slot`, and each unoccupied cell of a grid
 * `wf:layout`.
 *
 * Visual: a single clickable bar with a `+` icon and a contextual hint.
 * The whole area is the click target; on click it opens a FloatKit menu
 * (`@service menu`) anchored to the button, hosting the shared
 * `EditorBlockPickerMenu` with the palette + pick callback.
 *
 * Responsive degradation: the root sets a `wireframe-empty` CSS
 * container so SCSS can collapse the visible hint text below ~12rem.
 * A sibling `__tooltip-host` element is `display: none` while the
 * hint is visible and `inset: 0` (covering the button) when the hint
 * is hidden — a FloatKit tooltip registered on that host only triggers
 * in the narrow case, so the hint never appears twice at once.
 *
 * Args:
 *   - `@hint` (string) — pre-translated message. Visible label when
 *     there's room; tooltip content when there isn't.
 *   - `@palette` (Array<{name, displayName, icon}>) — already filtered
 *     to user-pickable blocks and sorted. Pass `buildBlockPalette` from
 *     `lib/palette.js`.
 *   - `@onPick` (`(blockEntry) => void`) — fired when the author picks
 *     a block from the popover. The placeholder closes the menu after
 *     `onPick` returns.
 */
export default class EditorEmptyDropPlaceholder extends Component {
  @service menu;
  @service tooltip;

  /* Captured on insert via didInsert. The button is also the FloatKit
     menu anchor — `menu.show()` positions the popover relative to it. */
  _buttonEl = null;

  /* The open FloatKit menu instance, returned by `menu.show()`. Held
     so `handlePick` can close the popover after firing `@onPick`. */
  _menuInstance = null;

  /* FloatKit tooltip instance returned by `tooltip.register()`. Held so
     the destroy hook can release the listeners when the placeholder
     unmounts. Listeners are attached on the `__tooltip-host` child, not
     the button — that's how the narrow-only behaviour stays CSS-driven. */
  _tooltipInstance = null;

  @action
  captureButton(element) {
    this._buttonEl = element;
  }

  @action
  registerTooltip(element) {
    this._tooltipInstance = this.tooltip.register(element, {
      content: this.args.hint,
    });
  }

  @action
  cleanupTooltip() {
    this._tooltipInstance?.destroy?.();
    this._tooltipInstance = null;
  }

  @action
  async openPicker(event) {
    // Slots and empty containers sit inside `<BlockChrome>`, whose own
    // click handler unconditionally calls `event.preventDefault()` +
    // `selectBlock(...)` and triggers a re-render. Without this stop the
    // chrome's action eats the click — the menu appears to never open.
    event?.stopPropagation?.();
    event?.preventDefault?.();
    this._menuInstance = await this.menu.show(this._buttonEl, {
      component: EditorBlockPickerMenu,
      identifier: "wireframe-block-picker",
      placement: "bottom",
      fallbackPlacements: ["top", "right", "left"],
      maxWidth: 320,
      data: {
        palette: this.args.palette,
        onPick: this.handlePick,
      },
    });
  }

  @action
  handlePick(blockEntry) {
    this.args.onPick?.(blockEntry);
    this._menuInstance?.close?.();
    this._menuInstance = null;
  }

  <template>
    <button
      type="button"
      class="wireframe-empty-drop-placeholder"
      {{didInsert this.captureButton}}
      {{on "click" this.openPicker}}
    >
      <span class="wireframe-empty-drop-placeholder__icon">
        {{dIcon "plus"}}
      </span>
      <span class="wireframe-empty-drop-placeholder__hint">{{@hint}}</span>
      <span
        class="wireframe-empty-drop-placeholder__tooltip-host"
        aria-hidden="true"
        {{didInsert this.registerTooltip}}
        {{willDestroy this.cleanupTooltip}}
      ></span>
    </button>
  </template>
}
