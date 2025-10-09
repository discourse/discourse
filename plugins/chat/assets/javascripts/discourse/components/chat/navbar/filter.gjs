import DButton from "discourse/components/d-button";

const ChatNavbarFilter = <template>
  <DButton
    @icon={{if @isFiltering "filter-circle-xmark" "filter"}}
    @action={{@onToggleFilter}}
    class="btn-transparent"
  />
</template>;

export default ChatNavbarFilter;
