// @ts-check
import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";

/**
 * One row in the palette panel. Renders the block's icon + display name,
 * an optional description tooltip, and is the drag source for inserting a
 * fresh entry onto the canvas.
 *
 * The drag payload uses the `ve-palette-block` kind so drop targets can
 * distinguish a palette-driven insert from a chrome-to-chrome move.
 */
export default class PaletteEntry extends Component {
  @service visualEditor;

  /**
   * Drag-start callback for the source modifier. We don't surface palette
   * drags through the editor service's `dragSourceKey` (that's the
   * "move" model), so this is a no-op for now — kept as a hook in case
   * Phase 7+ wants to track the in-flight palette drag.
   */
  @action
  handleDragStart() {}

  <template>
    <div
      class="visual-editor-palette-entry"
      role="button"
      tabindex="0"
      title={{@entry.description}}
      {{dDragAndDropSource
        kind="ve-palette-block"
        data=(hash blockName=@entry.name defaultArgs=@entry.previewArgs)
        onDragStart=this.handleDragStart
        onDragEnd=this.visualEditor.endDrag
      }}
    >
      <span class="visual-editor-palette-entry__icon">
        {{dIcon @entry.icon}}
      </span>
      <div class="visual-editor-palette-entry__text">
        <span class="visual-editor-palette-entry__label">
          {{@entry.displayName}}
        </span>
        {{#if @entry.description}}
          <span class="visual-editor-palette-entry__description">
            {{@entry.description}}
          </span>
        {{/if}}
      </div>
    </div>
  </template>
}
