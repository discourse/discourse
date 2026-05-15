import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class GifsResult extends Component {
  get style() {
    const { width, height } = this.args.gif;

    if (width && height) {
      return trustHTML(`--aspect-ratio: ${width / height};`);
    }
  }

  @action
  keyDown(event) {
    if (event.key === "Enter") {
      this.args.pick(this.args.gif);
    }
  }

  <template>
    <div
      {{on "click" (fn @pick @gif)}}
      {{on "keydown" this.keyDown}}
      role="button"
      tabindex="0"
      class={{dConcatClass
        "gifs-result"
        (if @gif.isCategory "gifs-result--category")
      }}
    >
      <img
        class="gifs-result__img"
        alt={{@gif.title}}
        title={{@gif.title}}
        src={{@gif.preview}}
        style={{this.style}}
        width={{@gif.width}}
        height={{@gif.height}}
      />
      {{#if @gif.isCategory}}
        <span class="gifs-result__category-label">{{@gif.title}}</span>
      {{/if}}
    </div>
  </template>
}
