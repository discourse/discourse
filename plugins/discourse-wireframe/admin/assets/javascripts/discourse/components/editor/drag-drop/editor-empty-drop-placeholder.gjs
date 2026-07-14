// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import EditorBlockPickerMenu from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/editor-block-picker-menu";

/**
 * Unified empty-state placeholder shown wherever the editor needs an
 * "insert a block here" affordance: an empty outlet, an empty non-grid
 * container, an empty merged cell, and each unoccupied cell of a grid
 * `wf:layout`.
 *
 * Visual: a single clickable bar with a `+` icon and a contextual hint.
 * The whole area is the click target; on click it opens a FloatKit menu
 * (`@service menu`) anchored to the button, hosting the shared
 * `EditorBlockPickerMenu` with the palette + pick callback.
 *
 * Responsive degradation: the root sets a `wireframe-empty` CSS container so
 * SCSS collapses the visible hint text below ~12rem, leaving just the centered
 * `+`. The button carries an `aria-label` with the same hint, so it stays named
 * for assistive tech in the icon-only state.
 *
 * Args:
 *   - `@hint` (string) — pre-translated message. Shown as the visible label
 *     when there's room, and always the button's accessible name.
 *   - `@palette` (Array<{name, displayName, icon, ...}>) — the shared
 *     `buildBlockPalette` rows, already filtered to user-pickable blocks.
 *   - `@targetOutletName` (string) — the outlet the drop target lives in.
 *     The picker filters its suggestions to blocks valid for this outlet.
 *   - `@onPick` (`(blockEntry) => void`) — fired when the author picks
 *     a block from the popover. The placeholder closes the menu after
 *     `onPick` returns.
 *   - `@onActivate` (`() => void`) — fired when the placeholder is
 *     clicked, before the picker opens. The click stops propagation so
 *     the surrounding chrome's own selection handler never runs, so the
 *     owner wires this to select the block the drop target belongs to
 *     (the empty container / slot, or the grid layout for a cell).
 */
export default class EditorEmptyDropPlaceholder extends Component {
  @service menu;

  /* Captured on insert via didInsert. The button is also the FloatKit
     menu anchor — `menu.show()` positions the popover relative to it. */
  #buttonEl = null;

  /* The open FloatKit menu instance, returned by `menu.show()`. Held
     so `handlePick` can close the popover after firing `@onPick`. */
  #menuInstance = null;

  @action
  captureButton(element) {
    this.#buttonEl = element;
  }

  @action
  async openPicker(event) {
    // The surrounding `<BlockChrome>` click handler calls
    // `event.preventDefault()` + `selectBlock(...)` and triggers a
    // re-render. Stop propagation so the chrome doesn't swallow the
    // click before the menu opens.
    event?.stopPropagation?.();
    event?.preventDefault?.();
    // Because we stopped propagation, the chrome's own selection never
    // fires. Select the owning block ourselves so the inspector tracks
    // the container / slot / layout the author is dropping into.
    this.args.onActivate?.();
    this.#menuInstance = await this.menu.show(this.#buttonEl, {
      component: EditorBlockPickerMenu,
      identifier: "wireframe-block-picker",
      placement: "bottom",
      fallbackPlacements: ["top", "right", "left"],
      maxWidth: 320,
      data: {
        palette: this.args.palette,
        targetOutletName: this.args.targetOutletName,
        onPick: this.handlePick,
      },
    });
  }

  @action
  handlePick(blockEntry) {
    this.args.onPick?.(blockEntry);
    this.#menuInstance?.close?.();
    this.#menuInstance = null;
  }

  <template>
    <button
      type="button"
      class="wireframe-empty-drop-placeholder"
      aria-label={{@hint}}
      {{didInsert this.captureButton}}
      {{on "click" this.openPicker}}
    >
      <span class="wireframe-empty-drop-placeholder__icon">
        {{dIcon "plus"}}
      </span>
      <span class="wireframe-empty-drop-placeholder__hint">{{@hint}}</span>
    </button>
  </template>
}
