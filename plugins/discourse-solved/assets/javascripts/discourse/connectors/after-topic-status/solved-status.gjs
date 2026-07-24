import { and, eq, or } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const SolvedStatus = <template>
  {{~#if
    (or @outletArgs.topic.has_accepted_answer @outletArgs.topic.accepted_answer)
  ~}}
    <span
      title={{i18n "topic_statuses.solved.help"}}
      class="topic-status --solved"
    >{{dIcon "far-square-check"}}</span>
  {{~else if
    (and
      @outletArgs.topic.can_have_answer (eq @outletArgs.context "topic-list")
    )
  ~}}
    <span
      title={{i18n "solved.has_no_accepted_answer"}}
      class="topic-status --unsolved"
    >{{dIcon "far-square"}}</span>
  {{~/if~}}
</template>;

export default SolvedStatus;
