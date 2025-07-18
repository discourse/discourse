import { fn } from "@ember/helper";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

const ToggleInvitees = <template>
  <div class="invitees-type-filter">
    <DButton
      @label="discourse_post_event.models.invitee.status.going"
      class={{concatClass
        "btn toggle-going"
        (if (eq @viewType "going") "btn-danger" "btn-default")
      }}
      @action={{fn @toggle "going"}}
    />

    <DButton
      @label="discourse_post_event.models.invitee.status.interested"
      class={{concatClass
        "btn toggle-interested"
        (if (eq @viewType "interested") "btn-danger" "btn-default")
      }}
      @action={{fn @toggle "interested"}}
    />

    <DButton
      @label="discourse_post_event.models.invitee.status.not_going"
      class={{concatClass
        "btn toggle-not-going"
        (if (eq @viewType "not_going") "btn-danger" "btn-default")
      }}
      @action={{fn @toggle "not_going"}}
    />
  </div>
</template>;

export default ToggleInvitees;
