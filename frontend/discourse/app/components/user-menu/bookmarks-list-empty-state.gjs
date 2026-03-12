import { trustHTML } from "@ember/template";
import EmptyState from "discourse/ui-kit/d-empty-state";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const BookmarksListEmptyState = <template>
  <EmptyState
    @title={{i18n "user.no_bookmarks_title"}}
    @body={{trustHTML (i18n "user.no_bookmarks_body" icon=(icon "bookmark"))}}
  />
</template>;

export default BookmarksListEmptyState;
