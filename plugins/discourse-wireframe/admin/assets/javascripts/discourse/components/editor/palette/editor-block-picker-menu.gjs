// @ts-check
import { fn } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * Menu body shown by the FloatKit `menu` service when an empty-drop
 * placeholder is clicked. Receives the canvas palette + a pick callback
 * via `@data` (injected by `menu.show(triggerEl, { component, data })`).
 *
 * Rendered as a 2-column grid of block chips. Clicking a chip fires
 * `@data.onPick(blockEntry)` and the calling placeholder closes the menu.
 *
 * `@data` shape:
 *   - `palette`: `Array<{name, displayName, icon}>` already filtered to
 *     user-pickable entries and sorted.
 *   - `onPick`: `(blockEntry) => void` invoked with the chosen entry.
 *   - `close`: `() => void` provided by FloatKit so chip clicks can
 *     dismiss the menu after firing `onPick`.
 */
const EditorBlockPickerMenu = <template>
  <div class="wireframe-block-picker">
    <div class="wireframe-block-picker__header">
      <span>{{i18n "wireframe.canvas.grid_overlay.pick_block"}}</span>
    </div>
    <div class="wireframe-block-picker__grid" role="menu">
      {{#each @data.palette as |blockEntry|}}
        <DButton
          class="wireframe-block-picker__chip"
          role="menuitem"
          @icon={{blockEntry.icon}}
          @translatedLabel={{blockEntry.displayName}}
          @translatedTitle={{blockEntry.displayName}}
          @action={{fn @data.onPick blockEntry}}
        />
      {{/each}}
    </div>
  </div>
</template>;

export default EditorBlockPickerMenu;
