import { i18n } from "discourse-i18n";

const VoteCountTrigger = <template>
  <button
    type="button"
    aria-label={{i18n "topic_voting.show_voters"}}
    ...attributes
  >
    {{yield}}
  </button>
</template>;

export default VoteCountTrigger;
