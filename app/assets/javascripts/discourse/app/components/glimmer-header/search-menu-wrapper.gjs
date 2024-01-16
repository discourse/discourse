import SearchMenuPanel from "../search-menu-panel";

const SearchMenuWrapper = <template>
  <div
    class="search-menu glimmer-search-menu"
    data-click-outside="true"
    aria-live="polite"
  >
    <SearchMenuPanel @closeSearchMenu={{@closeSearchMenu}} />
  </div>
</template>;

export default SearchMenuWrapper;
