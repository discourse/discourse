import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel } from "@ember/runloop";
import concatClass from "discourse/helpers/concat-class";
import discourseLater from "discourse/lib/later";

class Block {
  @tracked show = false;
  @tracked shown = false;
  @tracked blinking = false;

  constructor(args = {}) {
    this.show = args.show ?? false;
    this.shown = args.shown ?? false;
  }
}

const BLOCKS_SIZE = 20; // changing this requires to change css accordingly

export default class AiBlinkingAnimation extends Component {
  blocks = [...Array.from({ length: BLOCKS_SIZE }, () => new Block())];

  #nextBlockBlinkingTimer;
  #blockBlinkingTimer;
  #blockShownTimer;

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

    this.#nextBlockBlinkingTimer = discourseLater(
      this,
      () => {
        this.#nextBlock(block).blinking = true;
      },
      250
    );

    this.#blockBlinkingTimer = discourseLater(
      this,
      () => {
        block.blinking = false;
      },
      500
    );
  }

  @action
  onShowing(block) {
    if (!block.show) {
      return;
    }

    this.#blockShownTimer = discourseLater(
      this,
      () => {
        this.#nextBlock(block).show = true;
        this.#nextBlock(block).shown = true;

        if (this.blocks.lastObject === block) {
          this.blocks.firstObject.blinking = true;
        }
      },
      250
    );
  }

  @action
  teardownAnimation() {
    cancel(this.#blockShownTimer);
    cancel(this.#nextBlockBlinkingTimer);
    cancel(this.#blockBlinkingTimer);
  }

  #nextBlock(currentBlock) {
    if (currentBlock === this.blocks.lastObject) {
      return this.blocks.firstObject;
    } else {
      return this.blocks.objectAt(this.blocks.indexOf(currentBlock) + 1);
    }
  }

  <template>
    <ul class="ai-blinking-animation" {{didInsert this.setupAnimation}}>
      {{#each this.blocks as |block|}}
        <li
          class={{concatClass
            "ai-blinking-animation__list-item"
            (if block.show "show")
            (if block.shown "is-shown")
            (if block.blinking "blink")
          }}
          {{didUpdate (fn this.onBlinking block) block.blinking}}
          {{didUpdate (fn this.onShowing block) block.show}}
          {{willDestroy this.teardownAnimation}}
        ></li>
      {{/each}}
    </ul>
  </template>
}
