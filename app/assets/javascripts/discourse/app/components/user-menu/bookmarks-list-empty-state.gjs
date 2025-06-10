import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const BookmarksListEmptyState = <template>
  <div class="empty-state">
    <span class="empty-state-title">
      {{i18n "user.no_bookmarks_title"}}
    </span>
    <div class="empty-state-body">
      <p>
        {{htmlSafe (i18n "user.no_bookmarks_body" icon=(icon "bookmark"))}}
      </p>
    </div>
  </div>
</template>;

export default BookmarksListEmptyState;
