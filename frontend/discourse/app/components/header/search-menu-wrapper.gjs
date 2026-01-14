import Component from "@glimmer/component";
import { service } from "@ember/service";
import MenuPanel from "discourse/components/menu-panel";
import SearchMenu from "discourse/components/search-menu";
import concatClass from "discourse/helpers/concat-class";

export default class SearchMenuWrapper extends Component {
  @service site;

  get animationClass() {
    return this.site.mobileView || this.site.narrowDesktopView
      ? "slide-in"
      : "drop-down";
  }

  <template>
    <div
      class="search-menu glimmer-search-menu"
      aria-live="polite"
      ...attributes
    >
      <MenuPanel class={{concatClass this.animationClass "search-menu-panel"}}>
        <SearchMenu
          @onClose={{@closeSearchMenu}}
          @inlineResults={{true}}
          @autofocusInput={{true}}
          @location="header"
          @searchInputId={{@searchInputId}}
        />
      </MenuPanel>
    </div>
  </template>
}
