import { hash } from "@ember/helper";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

/** Runs on every dragover, so it stays a cheap synchronous read. */
const isUnlocked = ({ source }) => !source.data.locked;

export default <template>
  <div class="styleguide-drag-and-drop">
    <div class="styleguide-drag-and-drop__chips">
      <div
        class="styleguide-drag-and-drop__chip"
        {{dDragAndDropSource type="card" data=(hash locked=false)}}
      >{{i18n "styleguide.sections.drag_and_drop.unlocked"}}</div>

      <div
        class="styleguide-drag-and-drop__chip"
        {{dDragAndDropSource type="card" data=(hash locked=true)}}
      >{{i18n "styleguide.sections.drag_and_drop.locked"}}</div>
    </div>

    <div
      class="styleguide-drag-and-drop__zone"
      {{dDragAndDropTarget accepts="card" position="inside" canDrop=isUnlocked}}
    >{{i18n "styleguide.sections.drag_and_drop.unlocked_only"}}</div>
  </div>
</template>
