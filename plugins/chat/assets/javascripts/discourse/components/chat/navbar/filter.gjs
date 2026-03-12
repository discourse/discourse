import DButton from "discourse/ui-kit/d-button";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";

const ChatNavbarFilter = <template>
  <DButton
    @icon="discourse-chat-search"
    @action={{@onToggleFilter}}
    class={{concatClass
      "btn-transparent c-navbar__filter"
      (if @isFiltering "active")
    }}
  />
</template>;

export default ChatNavbarFilter;
