import { i18n } from "discourse-i18n";

const NewRepliesDot = <template>
  {{~! no whitespace ~}}
  <span class="topic-post-badges">&nbsp;<a
      href={{@topic.lastUnreadUrl}}
      title={{i18n "topic.has_new_replies"}}
      aria-label={{i18n "topic.has_new_replies"}}
      class="badge badge-notification new-replies"
    >&nbsp;</a></span>
  {{~! no whitespace ~}}
</template>;

export default NewRepliesDot;
