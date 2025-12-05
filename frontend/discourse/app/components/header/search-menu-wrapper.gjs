import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import MenuPanel from "discourse/components/menu-panel";
import SearchMenu from "discourse/components/search-menu";
import { animateClosing } from "discourse/lib/animation-utils";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";

export default class SearchMenuWrapper extends Component {
  @tracked searchMenuWrapper;

  @action
  setupWrapper(el) {
    this.searchMenuWrapper = el.querySelector(".search-menu-panel.drop-down");
  }

  @action
  async closeSearchMenu() {
    await animateClosing(this.searchMenuWrapper);
    this.args.closeSearchMenu();
  }

  <template>
    <div
      class="search-menu glimmer-search-menu"
      aria-live="polite"
      {{didInsert this.setupWrapper}}
      {{closeOnClickOutside
        this.closeSearchMenu
        (hash
          targetSelector=".search-menu-panel"
          secondaryTargetSelector=".search-dropdown"
        )
      }}
      ...attributes
    >
      <MenuPanel class="search-menu-panel drop-down">
        <SearchMenu
          @onClose={{this.closeSearchMenu}}
          @inlineResults={{true}}
          @autofocusInput={{true}}
          @location="header"
          @searchInputId={{@searchInputId}}
        />
      </MenuPanel>
    </div>
  </template>
}
