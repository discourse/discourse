import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";

export default class PointerDragExample extends Component {
  @tracked offset = 0;

  #start = 0;

  get knobStyle() {
    return trustHTML(`transform: translateX(${this.offset}px);`);
  }

  /** Restores what the gesture was previewing; an interrupted drag must not commit. */
  @action
  onDragCancel() {
    this.offset = this.#start;
  }

  @action
  onDrag(event, info) {
    this.offset = Math.min(240, Math.max(0, this.#start + info.delta.x));
  }

  @action
  onDragStart() {
    this.#start = this.offset;
  }

  <template>
    <div class="styleguide-drag-and-drop__track">
      <div
        class="styleguide-drag-and-drop__knob"
        style={{this.knobStyle}}
        {{dPointerDrag
          onDragStart=this.onDragStart
          onDrag=this.onDrag
          onDragCancel=this.onDragCancel
          draggingClass="--dragging"
        }}
      >{{i18n "styleguide.sections.drag_and_drop.knob"}}</div>
    </div>
  </template>
}
