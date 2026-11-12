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
      class={{dConcatClass
        "gifs-result"
        (if @gif.isCategory "gifs-result--category")
      }}
      role="button"
      tabindex="0"
      {{on "click" (fn @pick @gif)}}
      {{on "keydown" this.keyDown}}
    >
      <img
        alt={{@gif.title}}
        class="gifs-result__img"
        height={{@gif.height}}
        src={{@gif.preview}}
        style={{this.style}}
        title={{@gif.title}}
        width={{@gif.width}}
      />
      {{#if @gif.isCategory}}
        <span class="gifs-result__category-label">{{@gif.title}}</span>
      {{/if}}
    </div>
  </template>
}
