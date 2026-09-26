import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import MenuPanel from "discourse/components/menu-panel";
import SearchMenu from "discourse/components/search-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import SiteService from "discourse/services/site";

export default class SearchMenuWrapper extends Component {
  @service(() => SiteService) site;

  get animationClass() {
    return this.site.mobileView || this.site.narrowDesktopView
      ? "slide-in"
      : "drop-down";
  }

  <template>
    <div
      aria-live="polite"
      class="search-menu glimmer-search-menu"
      ...attributes
    >
      <MenuPanel class={{dConcatClass this.animationClass "search-menu-panel"}}>
        <SearchMenu
          @autofocusInput={{true}}
          @inlineResults={{true}}
          @location="header"
          @onClose={{@closeSearchMenu}}
          @searchInputId={{@searchInputId}}
        />
      </MenuPanel>
    </div>
  </template>
}
