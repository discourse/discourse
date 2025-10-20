import Component from "@glimmer/component";
import { service } from "@ember/service";
import MenuPanel from "discourse/components/menu-panel";
import SearchMenu from "discourse/components/search-menu";

export default class SearchMenuPanel extends Component {
  @service site;

  get animationClass() {
    return this.site.mobileView || this.site.narrowDesktopView
      ? "slide-in"
      : "drop-down";
  }

  <template>
    <MenuPanel
      @animationClass={{this.animationClass}}
      @panelClass="search-menu-panel"
    >
      <SearchMenu
        @onClose={{@closeSearchMenu}}
        @inlineResults={{true}}
        @autofocusInput={{true}}
        @location="header"
        @searchInputId={{@searchInputId}}
      />
    </MenuPanel>
  </template>
}
