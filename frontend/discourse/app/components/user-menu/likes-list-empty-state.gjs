import { trustHTML } from "@ember/template";
import EmptyState from "discourse/components/empty-state";
import getUrl from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const LikesListEmptyState = <template>
  <EmptyState
    @title={{i18n "user.no_likes_title"}}
    @body={{trustHTML
      (i18n
        "user.no_likes_body"
        preferencesUrl=(getUrl "/my/preferences/notifications")
      )
    }}
  />
</template>;

export default LikesListEmptyState;
