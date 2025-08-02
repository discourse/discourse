import Component from "@ember/component";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import avatar from "discourse/helpers/avatar";

export default class FlagUser extends Component {
  <template>
    <div class="flag-user">
      <LinkTo
        @route="adminUser"
        @models={{array this.user.id this.user.username}}
        class="flag-user-avatar"
      >
        {{avatar this.user imageSize="small"}}
      </LinkTo>
      <div class="flag-user-details">
        <div class="flag-user-who">
          <LinkTo
            @route="adminUser"
            @models={{array this.user.id this.user.username}}
            class="flag-user-username"
          >
            {{this.user.username}}
          </LinkTo>
          <div class="flag-user-date">
            {{ageWithTooltip this.date}}
          </div>
        </div>
        <div class="flag-user-extra">
          {{yield}}
        </div>
      </div>
    </div>
  </template>
}
