import GlimmerComponent from "@glimmer/component";
import { htmlSafe } from "@ember/template";

export default class SectionLink extends GlimmerComponent {
  get prefixCSS() {
    const color = this.args.prefixColor;
    if (!color || !color.match(/^\w{6}$/)) {
      return htmlSafe("");
    }
    return htmlSafe("color: #" + color);
  }
}
