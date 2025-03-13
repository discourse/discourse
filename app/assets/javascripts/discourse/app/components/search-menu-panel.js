import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class SearchMenuPanel extends Component {
  @service search;
  @service site;

  get animationClass() {
    return this.site.mobileView || this.site.narrowDesktopView
      ? this.args.hasClosingAnimation
        ? "slide-in is-closing"
        : "slide-in"
      : "drop-down";
  }
}
