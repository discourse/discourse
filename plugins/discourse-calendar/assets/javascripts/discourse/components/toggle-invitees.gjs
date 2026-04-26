import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import concatClass from "discourse/helpers/concat-class";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const ToggleInvitees = <template>
  <ul class="nav nav-pills invitees-type-filter">
    <li>
      <button
        type="button"
        class={{concatClass
          "toggle-going"
          (if (eq @viewType "going") "active")
        }}
        {{on "click" (fn @toggle "going")}}
      >
        {{i18n "discourse_post_event.models.invitee.status.going"}}
      </button>
    </li>
    <li>
      <button
        type="button"
        class={{concatClass
          "toggle-interested"
          (if (eq @viewType "interested") "active")
        }}
        {{on "click" (fn @toggle "interested")}}
      >
        {{i18n "discourse_post_event.models.invitee.status.interested"}}
      </button>
    </li>
    <li>
      <button
        type="button"
        class={{concatClass
          "toggle-not-going"
          (if (eq @viewType "not_going") "active")
        }}
        {{on "click" (fn @toggle "not_going")}}
      >
        {{i18n "discourse_post_event.models.invitee.status.not_going"}}
      </button>
    </li>
  </ul>
</template>;

export default ToggleInvitees;
