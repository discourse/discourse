import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";

/** Smallest dimension the example permits. */
const MIN_SIZE = 60;

export default class HandlesExample extends Component {
  @tracked height = 120;
  @tracked width = 220;
  @tracked x = 16;
  @tracked y = 16;

  /** The area the box may occupy; every bound below is measured from it. */
  captureStage = modifier((element) => {
    this.stageElement = element;
    return () => (this.stageElement = undefined);
  });

  stageElement;
  #start = {};

  get boxStyle() {
    return trustHTML(
      `width: ${this.width}px; height: ${this.height}px; ` +
        `transform: translate(${this.x}px, ${this.y}px);`
    );
  }

  get readout() {
    return `${Math.round(this.width)} × ${Math.round(this.height)}`;
  }

  /**
   * A west or north handle moves the box's origin as well as its size, so the
   * opposite edge stays put. Every result is clamped inside the stage.
   */
  @action
  onResize(direction, { delta }) {
    const { x, y, width, height } = this.#start;
    const { clientWidth: maxX, clientHeight: maxY } = this.stageElement;

    if (direction.includes("e")) {
      this.width = this.#clamp(width + delta.x, MIN_SIZE, maxX - x);
    }
    if (direction.includes("w")) {
      this.x = this.#clamp(x + delta.x, 0, x + width - MIN_SIZE);
      this.width = x + width - this.x;
    }
    if (direction.includes("s")) {
      this.height = this.#clamp(height + delta.y, MIN_SIZE, maxY - y);
    }
    if (direction.includes("n")) {
      this.y = this.#clamp(y + delta.y, 0, y + height - MIN_SIZE);
      this.height = y + height - this.y;
    }
  }

  @action
  onResizeStart() {
    this.#start = {
      height: this.height,
      width: this.width,
      x: this.x,
      y: this.y,
    };
  }

  #clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
  }

  <template>
    <div class="styleguide-drag-and-drop__stage" {{this.captureStage}}>
      <div class="styleguide-drag-and-drop__resizable" style={{this.boxStyle}}>
        {{this.readout}}
        <DResizeHandles
          @handleClass="styleguide-drag-and-drop__handle"
          @onResize={{this.onResize}}
          @onResizeStart={{this.onResizeStart}}
        />
      </div>
    </div>
  </template>
}
