import { trustHTML } from "@ember/template";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const BookmarksListEmptyState = <template>
  <DEmptyState
    @title={{i18n "user.no_bookmarks_title"}}
    @body={{trustHTML (i18n "user.no_bookmarks_body" icon=(dIcon "bookmark"))}}
  />
</template>;

export default BookmarksListEmptyState;
