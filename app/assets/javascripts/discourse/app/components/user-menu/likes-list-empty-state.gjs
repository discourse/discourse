import getUrl from "discourse/helpers/get-url";
import htmlSafe from "discourse/helpers/html-safe";
import i18n from "discourse/helpers/i18n";

const LikesListEmptyState = <template>
  <div class="empty-state">
    <span class="empty-state-title">
      {{i18n "user.no_likes_title"}}
    </span>
    <div class="empty-state-body">
      <p>
        {{htmlSafe
          (i18n
            "user.no_likes_body"
            preferencesUrl=(getUrl "/my/preferences/notifications")
          )
        }}
      </p>
    </div>
  </div>
</template>;
export default LikesListEmptyState;
