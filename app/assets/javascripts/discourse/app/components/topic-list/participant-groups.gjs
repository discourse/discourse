import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ParticipantGroups = <template>
  <div
    role="list"
    aria-label={{i18n "topic.participant_groups"}}
    class="participant-group-wrapper"
  >
    {{#each @groups as |group|}}
      <div class="participant-group">
        <a
          href={{group.url}}
          data-group-card={{group.name}}
          class="user-group trigger-group-card"
        >
          {{icon "users"}}
          {{group.name}}
        </a>
      </div>
    {{/each}}
  </div>
</template>;

export default ParticipantGroups;
