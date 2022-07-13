import GlimmerComponent from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";

export default class SectionLink extends GlimmerComponent {
  @cached
  get prefixCSS() {
    const color = this.args.prefixIconColor;
    if (!color || !color.match(/^\w{6}$/)) {
      return htmlSafe("");
    }
    return htmlSafe("color: #" + color);
  }
}
