import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";

const MentionsListEmptyState = <template>
  <DEmptyState
    @body={{i18n "user.no_mentions_body"}}
    @title={{i18n "user.no_mentions_title"}}
  />
</template>;

export default MentionsListEmptyState;
