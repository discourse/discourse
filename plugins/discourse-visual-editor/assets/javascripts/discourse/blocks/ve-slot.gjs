// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

/**
 * Template-defined drop target. A slot is a positioned cell in a
 * grid layout (`ve:layout`) that hasn't been filled yet — applying
 * a template like "Hero + 3" produces a `ve:slot` per intended
 * region. Dropping a block on a slot replaces the slot entry
 * in-place; deleting a multi-cell block re-creates a slot at the
 * same rect so the layout's footprint persists.
 *
 * On the live page the block renders nothing — the slot's CSS Grid
 * cell stays allocated (because the entry carries
 * `containerArgs.grid` like any positioned child) but its contents
 * are empty. Themes that want to collapse empty slots in production
 * can apply `display: none` to `.block-ve-slot`.
 *
 * In the editor, `block-chrome.gjs` detects the `ve:slot` block
 * name and substitutes a "Pick a block" placeholder for the
 * empty content area — same affordance the grid overlay renders
 * for auto-detected empty cells. All other chrome — selection,
 * the drag handle, the resize handle when grid-positioned — flows
 * through unchanged.
 */
@block("ve:slot", {
  displayName: "Slot",
  category: "Layout",
  icon: "border-none",
  description: "Template-defined drop target — pick a block to fill it.",
  paletteHidden: true,
})
export default class VESlot extends Component {
  <template>
    {{! Live page: render nothing. Editor: BlockChrome substitutes
        the EmptyCellPlaceholder when @blockName === "ve:slot". }}
  </template>
}
