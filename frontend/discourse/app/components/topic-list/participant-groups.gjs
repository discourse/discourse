import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ParticipantGroups = <template>
  <div
    aria-label={{i18n "topic.participant_groups"}}
    class="participant-group-wrapper"
    role="list"
  >
    {{#each @groups as |group|}}
      <div class="participant-group">
        <a
          class="user-group trigger-group-card"
          data-group-card={{group.name}}
          href={{group.url}}
        >
          {{dIcon "users"}}
          {{group.name}}
        </a>
      </div>
    {{/each}}
  </div>
</template>;

export default ParticipantGroups;
