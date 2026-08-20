import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class PreviewExample extends Component {
  /**
   * Mounts a preview into the offscreen container the modifier supplies, so
   * nothing around the source bleeds into the drag image.
   */
  @action
  renderPreview({ container }) {
    const badge = document.createElement("div");
    badge.className = "styleguide-drag-and-drop__preview";
    badge.textContent = i18n("styleguide.sections.drag_and_drop.preview_badge");
    container.append(badge);
    return () => badge.remove();
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div
        class="styleguide-drag-and-drop__chip"
        {{dDragAndDropSource
          type="card"
          dragPreview=this.renderPreview
          dragPreviewOffset=(hash x="0.75rem" y="0.75rem")
        }}
      >{{i18n "styleguide.sections.drag_and_drop.drag_me"}}</div>

      <div
        class="styleguide-drag-and-drop__zone"
        {{dDragAndDropTarget accepts="card" position="inside"}}
      >{{i18n "styleguide.sections.drag_and_drop.drop_here"}}</div>
    </div>
  </template>
}
