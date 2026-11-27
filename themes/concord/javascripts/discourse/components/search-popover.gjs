import SearchMenu from "discourse/components/search-menu";

const SearchPopover = <template>
  <div aria-live="polite" class="search-menu glimmer-search-menu">
    <div class="menu-panel drop-down search-menu-panel concord-search-panel">
      <SearchMenu
        @autofocusInput={{true}}
        @inlineResults={{true}}
        @location="header"
        @onClose={{@close}}
        @searchInputId="concord-search-input"
      />
    </div>
  </div>
</template>;

export default SearchPopover;
