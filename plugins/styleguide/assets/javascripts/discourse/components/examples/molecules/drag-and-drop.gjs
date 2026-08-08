import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

/**
 * The five drop positions the shared stylesheet draws, each paired with the
 * state class that produces it. Rendered as static swatches so the vocabulary is
 * readable without holding a drag open, and stamped with the real
 * `data-drop-target` attribute because the stylesheet gates every rule on it.
 */
const POSITIONS = [
  { state: "--drag-above", label: "above" },
  { state: "--drag-below", label: "below" },
  { state: "--drag-left", label: "left" },
  { state: "--drag-right", label: "right" },
  { state: "--drag-inside", label: "inside" },
];

const MIN_SIZE = 60;

export default class DragAndDropExample extends Component {
  @tracked items = ["Alpha", "Bravo", "Charlie"];
  @tracked width = 220;
  @tracked height = 120;

  positions = POSITIONS;
  #startWidth = 0;
  #startHeight = 0;

  get boxStyle() {
    return trustHTML(`width: ${this.width}px; height: ${this.height}px;`);
  }

  /**
   * Moves the dragged item next to the row it was dropped on.
   *
   * @param {string} target - The item the drop landed on.
   * @param {Object} params - The drop payload.
   * @param {Object} params.source - The dragged source, carrying `data.item`.
   * @param {string} params.position - Whether the drop landed before or after.
   */
  @action
  onDrop(target, { source, position }) {
    const dragged = source.data.item;
    if (dragged === target) {
      return;
    }

    const next = this.items.filter((item) => item !== dragged);
    const at = next.indexOf(target);
    next.splice(position === "before" ? at : at + 1, 0, dragged);
    this.items = next;
  }

  @action
  onResizeStart() {
    this.#startWidth = this.width;
    this.#startHeight = this.height;
  }

  /**
   * Maps the pointer delta onto the box, per compass direction.
   *
   * The component reports pointer geometry only, so turning that into a size —
   * including which directions grow as the pointer moves negatively — is the
   * consumer's job. That split is the point of the example.
   *
   * @param {string} direction - The compass payload of the dragged handle.
   * @param {Object} dragInfo - The reported gesture geometry.
   */
  @action
  onResize(direction, { delta }) {
    if (direction.includes("e")) {
      this.width = Math.max(MIN_SIZE, this.#startWidth + delta.x);
    }
    if (direction.includes("w")) {
      this.width = Math.max(MIN_SIZE, this.#startWidth - delta.x);
    }
    if (direction.includes("s")) {
      this.height = Math.max(MIN_SIZE, this.#startHeight + delta.y);
    }
    if (direction.includes("n")) {
      this.height = Math.max(MIN_SIZE, this.#startHeight - delta.y);
    }
  }

  <template>
    <div class="styleguide--drag-and-drop">
      <section class="styleguide--drag-and-drop__positions">
        <h3>{{i18n "styleguide.sections.drag_and_drop.positions_title"}}</h3>
        <p>{{i18n
            "styleguide.sections.drag_and_drop.positions_description"
          }}</p>

        <div class="styleguide--drag-and-drop__swatches">
          {{#each this.positions key="state" as |position|}}
            <div class="styleguide--drag-and-drop__swatch">
              <div
                data-drop-target
                class={{dConcatClass
                  "styleguide--drag-and-drop__box"
                  position.state
                }}
              >
                {{position.label}}
              </div>
              <code>{{position.state}}</code>
            </div>
          {{/each}}
        </div>
      </section>

      <section class="styleguide--drag-and-drop__live">
        <h3>{{i18n "styleguide.sections.drag_and_drop.live_title"}}</h3>
        <p>{{i18n "styleguide.sections.drag_and_drop.live_description"}}</p>

        <ul class="styleguide--drag-and-drop__list">
          {{#each this.items key="@identity" as |item|}}
            <li
              {{dDragAndDropSource type="styleguide-row" data=(hash item=item)}}
              {{dDragAndDropTarget
                accepts="styleguide-row"
                acceptsSelf=false
                onDrop=(fn this.onDrop item)
              }}
              class="styleguide--drag-and-drop__row"
            >
              {{item}}
            </li>
          {{/each}}
        </ul>
      </section>

      <section class="styleguide--drag-and-drop__resize">
        <h3>{{i18n "styleguide.sections.drag_and_drop.resize_title"}}</h3>
        <p>{{i18n "styleguide.sections.drag_and_drop.resize_description"}}</p>

        <div
          class="styleguide--drag-and-drop__resizable"
          style={{this.boxStyle}}
        >
          {{this.width}}&nbsp;&times;&nbsp;{{this.height}}
          <DResizeHandles
            @handleClass="styleguide--drag-and-drop__handle"
            @onResizeStart={{this.onResizeStart}}
            @onResize={{this.onResize}}
          />
        </div>
      </section>
    </div>
  </template>
}
