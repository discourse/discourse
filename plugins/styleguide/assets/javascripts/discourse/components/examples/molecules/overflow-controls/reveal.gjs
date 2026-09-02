import Component from "@glimmer/component";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import DOverflowControls from "discourse/ui-kit/d-overflow-controls";

const SECTIONS = Array.from({ length: 12 }, (_, index) => `Item ${index + 1}`);

export default class OverflowControlsRevealExample extends Component {
  /** Keeps the yielded strip so the buttons above it can call reveal. */
  registerStrip = modifier((_element, [strip]) => {
    this.#strip = strip;
  });

  sections = SECTIONS;

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
    const item = document.querySelector(
      `.styleguide-overflow-controls__reveal [data-index="${index}"]`
    );
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

    <div
      class="styleguide-overflow-controls styleguide-overflow-controls--narrow styleguide-overflow-controls__reveal"
    >
      <DOverflowControls
        @class="styleguide-overflow-controls__strip"
        as |strip|
      >
        <span {{this.registerStrip strip}}></span>
        {{#each this.sections as |section index|}}
          <span
            class="styleguide-overflow-controls__chip"
            data-index={{index}}
          >{{section}}</span>
        {{/each}}
      </DOverflowControls>
    </div>
  </template>
}
