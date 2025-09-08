import { htmlSafe } from "@ember/template";
import EmptyState from "discourse/components/empty-state";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const BookmarksListEmptyState = <template>
  <EmptyState
    @title={{i18n "user.no_bookmarks_title"}}
    @body={{htmlSafe (i18n "user.no_bookmarks_body" icon=(icon "bookmark"))}}
  />
</template>;

export default BookmarksListEmptyState;
