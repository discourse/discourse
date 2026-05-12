// @ts-check
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

/**
 * Drop target rendered inside the outlet boundary when the outlet has no
 * blocks. Without this, an empty outlet has no `<BlockChrome>` to host a
 * drop zone, so the palette can't be used to populate it.
 *
 * Accepts both kinds:
 *  - `ve-palette-block` → `insertBlock` with `targetKey: null` (appends).
 *  - `ve-block` → `moveBlock` with `targetKey: null` (moves the dragged
 *    block to this outlet's root).
 */
export default class EditorEmptyOutletDropZone extends Component {
  @service visualEditor;

  acceptedDragKinds = ["ve-block", "ve-palette-block"];

  @action
  canDrop({ source }) {
    if (source?.kind === "ve-palette-block") {
      return this.visualEditor.canInsertBlockAt({
        blockName: source.data?.blockName,
        targetOutletName: this.args.outletName,
      });
    }
    return this.visualEditor.canDropAt({
      targetOutletName: this.args.outletName,
    });
  }

  @action
  applyDrop({ source }) {
    if (source?.kind === "ve-palette-block") {
      this.visualEditor.insertBlock({
        blockName: source.data.blockName,
        defaultArgs: source.data.defaultArgs,
        targetKey: null,
        position: "after",
        targetOutletName: this.args.outletName,
      });
    } else {
      this.visualEditor.moveBlock({
        sourceKey: source.data.blockKey,
        targetKey: null,
        position: "after",
        targetOutletName: this.args.outletName,
      });
    }
    this.visualEditor.endDrag();
  }

  <template>
    <div
      class="visual-editor-empty-outlet-drop-zone"
      {{dDragAndDropTarget
        accepts=this.acceptedDragKinds
        position="after"
        canDrop=this.canDrop
        onDrop=this.applyDrop
      }}
    >
      <span class="visual-editor-empty-outlet-drop-zone__icon">
        {{dIcon "plus"}}
      </span>
      <span>{{i18n "visual_editor.canvas.empty_outlet_hint"}}</span>
    </div>
  </template>
}
