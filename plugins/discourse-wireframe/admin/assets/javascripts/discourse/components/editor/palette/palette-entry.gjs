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
 * The drag payload uses the `wf-palette-block` type so drop targets can
 * distinguish a palette-driven insert from a chrome-to-chrome move.
 */
export default class PaletteEntry extends Component {
  @service wireframeDragSession;

  /**
   * Drag-start callback. Records the palette entry as the drag source so
   * dragover-time consumers (the unified drop coordinator) can build labels like
   * "Add Heading here" before the drop fires. `sourceKey` stays null — palette
   * drags aren't moves.
   */
  @action
  handleDragStart({ source }) {
    this.wireframeDragSession.startPaletteDrag(source.data);
  }

  <template>
    <div
      class="wireframe-palette-entry"
      role="button"
      tabindex="0"
      title={{@entry.description}}
      data-block-name={{@entry.name}}
      {{dDragAndDropSource
        type="wf-palette-block"
        data=(hash blockName=@entry.name)
        onDragStart=this.handleDragStart
        onDrop=this.wireframeDragSession.endDrag
      }}
    >
      <span class="wireframe-palette-entry__icon">
        {{dIcon @entry.icon}}
      </span>
      <div class="wireframe-palette-entry__text">
        <span class="wireframe-palette-entry__label">
          {{@entry.displayName}}
        </span>
        {{#if @entry.description}}
          <span class="wireframe-palette-entry__description">
            {{@entry.description}}
          </span>
        {{/if}}
      </div>
    </div>
  </template>
}
