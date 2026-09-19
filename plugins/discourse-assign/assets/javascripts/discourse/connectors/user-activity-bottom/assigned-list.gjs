import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AssignedList extends Component {
  @service currentUser;

  <template>
    <li class="user-activity-bottom-outlet assigned-list" ...attributes>
      {{#if this.currentUser.can_assign_globally}}
        <LinkTo @route="userActivity.assigned">
          {{dIcon "user-plus"}}
          {{i18n "discourse_assign.assigned"}}
        </LinkTo>
      {{/if}}
    </li>
  </template>
}
