import { and, eq, or } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const SolvedStatus = <template>
  {{~#if
    (or @outletArgs.topic.has_accepted_answer @outletArgs.topic.accepted_answer)
  ~}}
    <span
      class="topic-status --solved"
      title={{i18n "topic_statuses.solved.help"}}
    >{{dIcon "far-square-check"}}</span>
  {{~else if
    (and
      @outletArgs.topic.can_have_answer (eq @outletArgs.context "topic-list")
    )
  ~}}
    <span
      class="topic-status --unsolved"
      title={{i18n "solved.has_no_accepted_answer"}}
    >{{dIcon "far-square"}}</span>
  {{~/if~}}
</template>;

export default SolvedStatus;
