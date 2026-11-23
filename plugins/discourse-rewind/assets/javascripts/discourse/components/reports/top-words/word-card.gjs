import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import getURL from "discourse/lib/get-url";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const MYSTERY_ICONS = [
  "floppy_disk",
  "videocassette",
  "computer_disk",
  "pager",
  "fax",
];

export default class WordCard extends Component {
  @tracked isFlipped = false;

  get mysteryIcon() {
    const name = MYSTERY_ICONS[this.args.index];
    if (name) {
      return {
        name,
        url: getURL(
          `/plugins/discourse-rewind/images/one-bit/${name.replaceAll("_", "-")}.svg`
        ),
      };
    }
  }

  /**
   * Long words step down a size so they fit the card, keeping the pixel font on its grid.
   */
  get lengthModifier() {
    const length = this.args.word.length;
    if (length > 9) {
      return "--longer";
    }
    return length > 6 ? "--long" : null;
  }

  @action
  flip() {
    this.isFlipped = !this.isFlipped;
  }

  <template>
    <button
      aria-pressed={{if this.isFlipped "true" "false"}}
      class={{dConcatClass "rewind-word-card" (if this.isFlipped "is-flipped")}}
      type="button"
      {{on "click" this.flip}}
    >
      {{#if this.isFlipped}}
        <span class="rewind-word-card__front">
          <span
            class={{dConcatClass "rewind-word-card__word" this.lengthModifier}}
          >{{@word}}</span>
          <span class="rewind-word-card__count">{{@count}}x</span>
        </span>
      {{else}}
        <span class="rewind-word-card__back">
          <span class="rewind-word-card__plate">
            {{#let this.mysteryIcon as |icon|}}
              {{#if icon}}
                <img
                  alt={{icon.name}}
                  class="rewind-word-card__icon"
                  height="48"
                  src={{icon.url}}
                  title={{icon.name}}
                  width="48"
                />
              {{/if}}
            {{/let}}
          </span>
        </span>
      {{/if}}
    </button>
  </template>
}
