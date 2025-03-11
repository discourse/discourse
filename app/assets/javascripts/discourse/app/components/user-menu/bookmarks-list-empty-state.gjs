import i18n from "discourse/helpers/i18n";
import htmlSafe from "discourse/helpers/html-safe";
import icon from "discourse/helpers/d-icon";
const BookmarksListEmptyState = <template><div class="empty-state">
  <span class="empty-state-title">
    {{i18n "user.no_bookmarks_title"}}
  </span>
  <div class="empty-state-body">
    <p>
      {{htmlSafe (i18n "user.no_bookmarks_body" icon=(icon "bookmark"))}}
    </p>
  </div>
</div></template>;
export default BookmarksListEmptyState;