import DButton from "discourse/components/d-button";

const SearchButton = <template>
  <DButton
    @icon="magnifying-glass"
    @route="chat.search"
    class="btn-transparent"
  />
</template>;

export default SearchButton;
