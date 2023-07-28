import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import discourseLater from "discourse-common/lib/later";
import { cancel } from "@ember/runloop";

class Block {
  @tracked show = false;
  @tracked shown = false;
  @tracked blinking = false;

  constructor(args = {}) {
    this.show = args.show ?? false;
    this.shown = args.shown ?? false;
  }
}

const ANIMATION_TIME = 500;
const BLOCKS_SIZE = 20; // changing this requires to change css accordingly

export default class AiSummarySkeleton extends Component {
  blocks = [...Array.from({ length: BLOCKS_SIZE }, () => new Block())];

  #onBlockBlinkingTimer;
  #onBlockShownTimer;

  @action
  setupAnimation() {
    this.blocks.firstObject.show = true;
    this.blocks.firstObject.shown = true;
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
        this.#nextBlock(block).blinking = true;
      },
      ANIMATION_TIME
    );
  }

  @action
  onShowing(block) {
    if (!block.show) {
      return;
    }

    this.#onBlockShownTimer = discourseLater(
      this,
      () => {
        this.#nextBlock(block).show = true;
        this.#nextBlock(block).shown = true;

        if (this.blocks.lastObject === block) {
          this.blocks.firstObject.blinking = true;
          return;
        }
      },
      ANIMATION_TIME
    );
  }

  @action
  teardownAnimation() {
    cancel(this.#onBlockBlinkingTimer);
    cancel(this.onBlockShownTimer);
  }

  #nextBlock(currentBlock) {
    if (currentBlock === this.blocks.lastObject) {
      return this.blocks.firstObject;
    } else {
      return this.blocks.objectAt(this.blocks.indexOf(currentBlock) + 1);
    }
  }
}
