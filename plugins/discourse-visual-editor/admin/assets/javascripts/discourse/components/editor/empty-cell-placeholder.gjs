// @ts-check
import { fn } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * "Pick a block to fill this cell" affordance — a `+` button that
 * opens a compact palette popover. Used in two places:
 *
 *  1. The grid overlay's auto-detected empty cells
 *     (`grid-overlay.gjs`) — one placeholder per unoccupied cell.
 *  2. The block chrome wrapping a `ve:slot` entry
 *     (`block-chrome.gjs`) — one placeholder per template-defined
 *     drop target.
 *
 * The parent owns the open/closed state so picking from one cell
 * automatically dismisses any other open picker (only one popover
 * visible at a time). Callbacks fire on click + on pick; the
 * `+` button itself is always rendered.
 *
 * Args:
 *   - `@palette` — `Array<{name, displayName, icon, previewArgs}>`
 *     the parent already filters / sorts for palette display.
 *   - `@isOpen` — true when this placeholder's popover should show.
 *   - `@onOpen` — called when the `+` button is clicked.
 *   - `@onClose` — called when the popover's close button is clicked.
 *   - `@onPick` — called with the picked block entry from `@palette`.
 */
const EmptyCellPlaceholder = <template>
  <DButton
    class="visual-editor-grid-cell__plus"
    @icon="plus"
    @title="visual_editor.canvas.grid_overlay.add_at_cell"
    @action={{@onOpen}}
  />
  {{#if @isOpen}}
    <div class="visual-editor-grid-cell__picker">
      <div class="visual-editor-grid-cell__picker-header">
        <span>{{i18n "visual_editor.canvas.grid_overlay.pick_block"}}</span>
        <DButton
          class="visual-editor-grid-cell__picker-close"
          @icon="xmark"
          @title="visual_editor.canvas.grid_overlay.cancel"
          @action={{@onClose}}
        />
      </div>
      <div class="visual-editor-grid-cell__picker-grid" role="menu">
        {{#each @palette as |blockEntry|}}
          <DButton
            class="visual-editor-grid-cell__picker-chip"
            role="menuitem"
            @icon={{blockEntry.icon}}
            @translatedLabel={{blockEntry.displayName}}
            @translatedTitle={{blockEntry.displayName}}
            @action={{fn @onPick blockEntry}}
          />
        {{/each}}
      </div>
    </div>
  {{/if}}
</template>;

export default EmptyCellPlaceholder;
