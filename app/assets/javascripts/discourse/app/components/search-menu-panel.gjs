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

<MenuPanel
  @animationClass={{this.animationClass}}
  @panelClass="search-menu-panel"
>
  <SearchMenu
    @onClose={{@closeSearchMenu}}
    @inlineResults={{true}}
    @autofocusInput={{true}}
  />
</MenuPanel>