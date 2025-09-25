import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

const ChatNavbarFilter = <template>
  <DButton
    @icon={{if @isFiltering "filter-circle-xmark" "filter"}}
    @action={{@onToggleFilter}}
    class={{concatClass "btn-transparent" (if @isFiltering "btn-primary")}}
  />
</template>;

export default ChatNavbarFilter;
