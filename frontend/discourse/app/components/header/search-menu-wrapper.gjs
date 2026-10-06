import Component from "@glimmer/component";
import { service } from "@ember/service";
import MenuPanel from "discourse/components/menu-panel";
import SearchMenu from "discourse/components/search-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class SearchMenuWrapper extends Component {
  @service site;

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
