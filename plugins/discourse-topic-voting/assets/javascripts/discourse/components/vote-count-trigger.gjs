import { i18n } from "discourse-i18n";

const VoteCountTrigger = <template>
  <button
    aria-label={{i18n "topic_voting.show_voters"}}
    type="button"
    ...attributes
  >
    {{yield}}
  </button>
</template>;

export default VoteCountTrigger;
