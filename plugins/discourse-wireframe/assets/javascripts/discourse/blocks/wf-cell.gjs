// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";

/**
 * An empty cell in a grid layout (`wf:layout`). A cell is a positioned
 * region — one cell or a span of several — that doesn't hold a block
 * yet. Applying a template like "Hero + 3" produces one cell per
 * intended region; dropping a block on a cell replaces the cell entry
 * in-place, and deleting a block that spans several cells re-creates a
 * cell at the same rect so the layout's footprint persists.
 *
 * It carries `containerArgs.grid` like any positioned child, so a
 * spanning empty region (a hero rail, a sidebar) survives save / load
 * as a single entry rather than collapsing into separate single-cell
 * positions. Single-cell empties don't need an entry — the grid
 * overlay surfaces those geometrically.
 *
 * On the live page the block renders nothing — its CSS Grid cell stays
 * allocated but its contents are empty. Themes that want to collapse
 * empty cells in production can apply `display: none` to
 * `.block-wf-cell`.
 *
 * In the editor, `block-chrome.gjs` detects the `wf:cell` block name
 * and substitutes a "Pick a block" placeholder for the empty content
 * area — the same affordance the grid overlay renders for the
 * single-cell empties. All other chrome — selection, the drag handle,
 * the resize handle when grid-positioned — flows through unchanged.
 */
@block("wf:cell", {
  displayName: "Cell",
  category: "Layout",
  icon: "border-none",
  description: "An empty grid cell — pick a block to fill it.",
  paletteHidden: true,
})
export default class WFCell extends Component {
  <template>
    {{! Live page: render nothing. Editor: BlockChrome substitutes
        the EditorEmptyDropPlaceholder when @blockName === "wf:cell". }}
  </template>
}
