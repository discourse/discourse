import { htmlSafe } from "@ember/template";
import EmptyState from "discourse/components/empty-state";
import getUrl from "discourse/helpers/get-url";
import { i18n } from "discourse-i18n";

const LikesListEmptyState = <template>
  <EmptyState
    @title={{i18n "user.no_likes_title"}}
    @body={{htmlSafe
      (i18n
        "user.no_likes_body"
        preferencesUrl=(getUrl "/my/preferences/notifications")
      )
    }}
  />
</template>;

export default LikesListEmptyState;
