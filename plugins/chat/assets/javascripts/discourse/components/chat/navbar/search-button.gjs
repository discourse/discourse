import DButton from "discourse/components/d-button";

const SearchButton = <template>
  <DButton
    @icon="magnifying-glass"
    @route="chat.search"
    class="btn-transparent chat-channel-search-btn"
  />
</template>;

export default SearchButton;
