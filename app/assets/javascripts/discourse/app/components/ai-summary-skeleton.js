import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import discourseLater from "discourse-common/lib/later";
import { cancel } from "@ember/runloop";

class Block {
  @tracked show = true;
  @tracked shown = true;
  @tracked blinking = false;
}

const ANIMATION_TIME = 500;
const BLOCKS_SIZE = 20; // changing this requires to change css accordingly

export default class AiSummarySkeleton extends Component {
  @tracked blocks = new TrackedArray([]);

  #onBlockBlinkingTimer;
  #onBlockAddedTimer;

  @action
  setupAnimation() {
    this.blocks.push(new Block());
  }

  @action
  onBlinking(block) {
    if (!block.blinking) {
      return;
    }

    block.show = false;

    this.#onBlockBlinkingTimer = discourseLater(
      this,
      () => {
        block.blinking = false;
        const currentIndex = this.blocks.indexOf(block);
        if (currentIndex === this.blocks.length - 1) {
          this.blocks.firstObject.blinking = true;
        } else {
          this.blocks.objectAt(currentIndex + 1).blinking = true;
        }
      },
      ANIMATION_TIME
    );
  }

  @action
  teardownAnimation() {
    cancel(this.#onBlockBlinkingTimer);
    cancel(this.#onBlockAddedTimer);
  }

  @action
  onBlockAdded() {
    if (this.blocks.length === BLOCKS_SIZE) {
      this.blocks.firstObject.blinking = true;
      return;
    }

    this.#onBlockAddedTimer = discourseLater(
      this,
      () => {
        this.blocks.push(new Block());
      },
      ANIMATION_TIME
    );
  }
}
