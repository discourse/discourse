// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";

const VALID_AXIS_ALIGN = ["start", "center", "end", "stretch"];

/**
 * Slot wrapper for grid-positioned children inside a `ve:layout` in
 * free-grid mode. Carries CSS Grid placement as its own args so the
 * underlying content block (Heading, Image, etc.) doesn't need to
 * know it's inside a grid.
 *
 * Marked `transparent: true` — the visual editor's outline expands
 * slots inline (rendering their inner block as the outline row) and
 * block chrome doesn't wrap them with the usual border/handle, so
 * the slot's `<div>` is the direct grid item and receives the
 * grid-column / grid-row styles cleanly. The grid editor's overlay
 * (Phase 7s.5) draws its own selection / drag / resize handles on
 * top of slot tiles when the parent grid is selected.
 *
 * Args:
 *  - `column` — CSS `grid-column` shorthand (e.g. `"1 / 4"` or `"auto"`).
 *  - `row` — CSS `grid-row` shorthand.
 *  - `align` — `align-self` for the slot in its grid track.
 *  - `justify` — `justify-self` for the slot in its grid track.
 *
 * Editor concerns (drag, snap, wrap-on-insert) live outside the
 * block — see `services/visual-editor.js`'s `_wrapInSlot` and the
 * grid-overlay component.
 */
@block("ve:slot", {
  container: true,
  paletteHidden: true,
  transparent: true,
  displayName: "Slot",
  icon: "border-none",
  category: "Layout",
  description:
    "Positioning wrapper for a child of a free-grid layout. Auto-managed by the editor; not user-pickable.",
  args: {
    column: {
      type: "string",
      default: "auto",
      ui: { label: "Column" },
    },
    row: {
      type: "string",
      default: "auto",
      ui: { label: "Row" },
    },
    align: {
      type: "string",
      default: "stretch",
      enum: VALID_AXIS_ALIGN,
      ui: { label: "Align (vertical)" },
    },
    justify: {
      type: "string",
      default: "stretch",
      enum: VALID_AXIS_ALIGN,
      ui: { label: "Justify (horizontal)" },
    },
  },
  previewArgs: { column: "auto", row: "auto" },
})
export default class VESlot extends Component {
  /**
   * The slot's own `<div>` would otherwise add a redundant box inside
   * the transparent chrome wrapper (which already carries the slot's
   * grid placement). `display: contents` makes this div participate
   * neither in layout nor box rendering — the children render as if
   * the slot's div weren't there, so the inner block's chrome sits
   * directly inside the transparent wrapper and aligns to the cell.
   */
  slotStyle = trustHTML(`display: contents;`);

  <template>
    <div class="ve-slot" style={{this.slotStyle}}>
      {{#each @children key="key" as |child|}}
        <child.Component />
      {{/each}}
    </div>
  </template>
}
