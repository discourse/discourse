/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("")
export default class AssignedList extends Component {
  <template>
    <li class="user-activity-bottom-outlet assigned-list" ...attributes>
      {{#if this.currentUser.can_assign}}
        <LinkTo @route="userActivity.assigned">
          {{icon "user-plus"}}
          {{i18n "discourse_assign.assigned"}}
        </LinkTo>
      {{/if}}
    </li>
  </template>
}
