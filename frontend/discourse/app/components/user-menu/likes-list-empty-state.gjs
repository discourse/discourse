import { trustHTML } from "@ember/template";
import getUrl from "discourse/lib/get-url";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";

const LikesListEmptyState = <template>
  <DEmptyState
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
