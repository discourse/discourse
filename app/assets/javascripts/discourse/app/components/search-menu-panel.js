import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class SearchMenuPanel extends Component {
  @service site;
  get animationClass() {
    return this.site.mobileView || this.site.narrowDesktopView
      ? "slide-in"
      : "drop-down";
  }
}
