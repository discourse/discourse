// @ts-check
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Visual affordance rendered inside the outlet boundary when the outlet
 * has no blocks. The actual drop handling lives on the parent
 * `<OutletBoundary>` — this element is purely a "drop something here"
 * hint so the empty outlet doesn't look inert.
 *
 * `pointer-events: none` in the stylesheet keeps the cursor passing
 * straight through to the boundary's drop modifier; otherwise the
 * boundary would never receive dragover when the cursor hovers this
 * div (deepest element wins).
 */
const EditorEmptyOutletDropZone = <template>
  <div class="visual-editor-empty-outlet-drop-zone">
    <span class="visual-editor-empty-outlet-drop-zone__icon">
      {{dIcon "plus"}}
    </span>
    <span>{{i18n "visual_editor.canvas.empty_outlet_hint"}}</span>
  </div>
</template>;

export default EditorEmptyOutletDropZone;
