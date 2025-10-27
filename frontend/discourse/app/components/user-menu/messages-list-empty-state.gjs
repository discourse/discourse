import { htmlSafe } from "@ember/template";
import EmptyState from "discourse/components/empty-state";
import icon from "discourse/helpers/d-icon";
import getUrl from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const MessagesListEmptyState = <template>
  <EmptyState
    @title={{i18n "user.no_messages_title"}}
    @body={{htmlSafe
      (i18n
        "user.no_messages_body"
        icon=(icon "envelope")
        aboutUrl=(getUrl "/about")
      )
    }}
  />
</template>;

export default MessagesListEmptyState;
