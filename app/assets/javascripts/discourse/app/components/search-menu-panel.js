import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class SearchMenuPanel extends Component {
  @service search;
  @service site;

  get animationClass() {
    return this.site.mobileView || this.site.narrowDesktopView
      ? "slide-in"
      : "drop-down";
  }

  get isEmpty() {
    return this.search.noResults || !this.search.activeGlobalSearchTerm;
  }
}
