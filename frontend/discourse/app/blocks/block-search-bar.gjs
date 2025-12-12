import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import SearchMenu from "discourse/components/search-menu";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
@block("search-bar")
export default class BlockSearchBar extends Component {
  <template>
    {{bodyClass "block-search-bar--visible"}}
    <div class="block-search-bar__container">
      <div class="block-search-bar__wrapper">
        <div class="block-search-bar__search-icon">
          {{icon "magnifying-glass"}}
        </div>
        <div class="block-search-bar__search-menu">
          <SearchMenu @searchInputId="block-search-bar" />
        </div>
      </div>
    </div>
  </template>
}
