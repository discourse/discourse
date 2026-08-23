import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

const ROWS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

export default <template>
  <div class="styleguide-drag-and-drop">
    <div
      class="styleguide-drag-and-drop__chip"
      {{dDragAndDropSource type="card"}}
    >{{i18n "styleguide.sections.drag_and_drop.drag_me"}}</div>

    <div
      class="styleguide-drag-and-drop__scroller"
      {{dDragAndDropAutoScroll types="card"}}
    >
      {{#each ROWS key="@index" as |row|}}
        <div
          class="styleguide-drag-and-drop__scroller-row"
          {{dDragAndDropTarget accepts="card"}}
        >{{i18n "styleguide.sections.drag_and_drop.row" number=row}}</div>
      {{/each}}
    </div>
  </div>
</template>
