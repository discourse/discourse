import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const ChatNavbarFilter = <template>
  <DButton
    @icon="discourse-chat-search"
    @action={{@onToggleFilter}}
    class={{dConcatClass
      "btn-transparent c-navbar__filter"
      (if @isFiltering "active")
    }}
  />
</template>;

export default ChatNavbarFilter;
