// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { isTesting } from "discourse/lib/environment";
/** @type {import("./block-preview-card.gjs").default} */
import BlockPreviewCard from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-preview-card";
/** @type {import("./block-thumbnail.gjs").default} */
import BlockThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-thumbnail";

/**
 * One block in the palette: an icon (or thumbnail) tile with its display name,
 * shared by the sidebar palette and the quick-inserter. Navigated and activated
 * by a `dRovingFocus` modifier on the parent grid (the tile itself owns no
 * keydown), so it carries `role="option"` and is laid out as a single tab stop
 * by the parent.
 *
 * Purely presentational: it knows nothing about insertion or dragging. Activation
 * is reported via `@onActivate`, and the sidebar makes a tile a drag source by
 * applying the drag modifier at the call site (the tile splats `...attributes`).
 *
 * Accessibility: the accessible name is exactly the display name (an explicit
 * `aria-label`, so the always-present description span doesn't bleed into it),
 * and the description is exposed via `aria-describedby` for assistive tech and
 * keyboard users — the visual description lives only in the hover preview.
 *
 * @param {Object} entry - A palette row from `buildBlockPalette`
 *   (`{name, displayName, icon, category, description, namespaceType,
 *   thumbnail, ...}`).
 * @param {(entry: Object) => void} [onActivate] - Called on the pointer
 *   activation gesture and on the roving Enter/Space activation.
 * @param {string} [activateOn="click"] - The pointer event that activates the
 *   tile. The inserter popover uses the default single click; the sidebar
 *   palette passes "dblclick", since its tiles are drag-first and a stray single
 *   click shouldn't fire an insert.
 */
export default class BlockTile extends Component {
  @service tooltip;

  /**
   * Registers the read-only hover preview tooltip on the tile. Hover-only (not
   * focus) so arrowing through the grid doesn't spam previews; non-interactive so
   * it never steals focus. Suppressed in tests, where FloatKit timing would make
   * assertions flaky and the preview adds no coverage.
   */
  registerPreview = modifier((element) => {
    if (isTesting()) {
      return;
    }
    const instance = this.tooltip.register(element, {
      component: BlockPreviewCard,
      data: { entry: this.args.entry },
      interactive: false,
      triggers: ["hover"],
      placement: "right",
      fallbackPlacements: ["left", "top", "bottom"],
      animated: false,
    });
    return () => instance.destroy();
  });

  /**
   * The pointer event that activates the tile (see `@activateOn`).
   *
   * @returns {string}
   */
  get activateOn() {
    return this.args.activateOn ?? "click";
  }

  /**
   * A unique id for this tile's description span, referenced by the tile's
   * `aria-describedby`. Derived from the component instance so two grids (the
   * sidebar and the inserter) rendering the same block never collide.
   *
   * @returns {string}
   */
  get descriptionId() {
    return `${guidFor(this)}-description`;
  }

  @action
  activate() {
    this.args.onActivate?.(this.args.entry);
  }

  <template>
    <div
      class="wireframe-block-tile"
      role="option"
      aria-label={{@entry.displayName}}
      aria-describedby={{this.descriptionId}}
      data-block-name={{@entry.name}}
      {{on this.activateOn this.activate}}
      {{this.registerPreview}}
      ...attributes
    >
      <BlockThumbnail
        class="wireframe-block-tile__thumbnail"
        @thumbnail={{@entry.thumbnail}}
        @icon={{@entry.icon}}
      />
      <span class="wireframe-block-tile__label">{{@entry.displayName}}</span>
      <span
        id={{this.descriptionId}}
        class="sr-only"
      >{{@entry.description}}</span>
    </div>
  </template>
}
