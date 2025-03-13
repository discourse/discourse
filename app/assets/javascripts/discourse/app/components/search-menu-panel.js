import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";

export default class SearchMenuPanel extends Component {
  @service search;
  @service site;

  @tracked loading = false;

  get animationClass() {
    return this.site.mobileView || this.site.narrowDesktopView
      ? this.args.hasClosingAnimation
        ? "slide-in is-closing"
        : "slide-in"
      : "drop-down";
  }

  get isEmpty() {
    return (
      this.search.noResults ||
      !this.search.activeGlobalSearchTerm ||
      this.loading
    );
  }
}
