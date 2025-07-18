import icon from "discourse/helpers/d-icon";
import getUrl from "discourse/helpers/get-url";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

const AssignsListEmptyState = <template>
  <div class="empty-state">
    <span class="empty-state-title">
      {{i18n "user.no_assignments_title"}}
    </span>
    <div class="empty-state-body">
      <p>
        {{htmlSafe
          (i18n
            "user.no_assignments_body"
            icon=(icon "user-plus")
            preferencesUrl=(getUrl "/my/preferences/notifications")
          )
        }}
      </p>
    </div>
  </div>
</template>;

export default AssignsListEmptyState;
