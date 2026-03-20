import { trustHTML } from "@ember/template";
import getUrl from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const AssignsListEmptyState = <template>
  <div class="empty-state">
    <span class="empty-state-title">
      {{i18n "user.no_assignments_title"}}
    </span>
    <div class="empty-state-body">
      <p>
        {{trustHTML
          (i18n
            "user.no_assignments_body"
            icon=(dIcon "user-plus")
            preferencesUrl=(getUrl "/my/preferences/notifications")
          )
        }}
      </p>
    </div>
  </div>
</template>;

export default AssignsListEmptyState;
