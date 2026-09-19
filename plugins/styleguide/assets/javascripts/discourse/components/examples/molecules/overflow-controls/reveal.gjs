import Component from "@glimmer/component";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import DOverflowControls from "discourse/ui-kit/d-overflow-controls";

const SECTIONS = Array.from({ length: 12 }, (_, index) => `Item ${index + 1}`);

export default class OverflowControlsRevealExample extends Component {
  /** Keeps each chip and the strip so the buttons above can call reveal. */
  registerChip = modifier((element, [index, strip]) => {
    this.#chips.set(index, element);
    this.#strip = strip;

    return () => this.#chips.delete(index);
  });

  sections = SECTIONS;

  #chips = new Map();
  #strip = null;

  @action
  revealNearest() {
    this.#reveal(8, "nearest");
  }

  @action
  revealCenter() {
    this.#reveal(3, "center");
  }

  #reveal(index, align) {
    const item = this.#chips.get(index);
    if (item && this.#strip) {
      this.#strip.reveal(item, { align });
    }
  }

  <template>
    <div class="styleguide-overflow-controls__controls">
      <DButton
        @action={{this.revealNearest}}
        @translatedLabel="Reveal item 9, nearest"
      />
      <DButton
        @action={{this.revealCenter}}
        @translatedLabel="Reveal item 4, centered"
      />
    </div>

    <div class="styleguide-overflow-controls --narrow">
      <DOverflowControls
        @class="styleguide-overflow-controls__strip"
        as |strip|
      >
        {{#each this.sections as |section index|}}
          <span
            class="styleguide-overflow-controls__chip"
            {{this.registerChip index strip}}
          >{{section}}</span>
        {{/each}}
      </DOverflowControls>
    </div>
  </template>
}
