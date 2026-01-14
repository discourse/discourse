import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import { getURLWithCDN } from "discourse/lib/get-url";

export default class CdnImg extends Component {
  get cdnSrc() {
    return getURLWithCDN(this.args.src);
  }

  get style() {
    if (this.args.width && this.args.height) {
      return htmlSafe(`--aspect-ratio: ${this.args.width / this.args.height};`);
    }
  }

  <template>
    {{#if @src}}
      <img
        ...attributes
        src={{this.cdnSrc}}
        width={{@width}}
        height={{@height}}
        style={{this.style}}
        alt=""
      />
    {{/if}}
  </template>
}
