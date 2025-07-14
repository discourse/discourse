import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { classNames, tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("li")
@classNames("user-activity-bottom-outlet", "assigned-list")
export default class AssignedList extends Component {
  <template>
    {{#if this.currentUser.can_assign}}
      <LinkTo @route="userActivity.assigned">
        {{icon "user-plus"}}
        {{i18n "discourse_assign.assigned"}}
      </LinkTo>
    {{/if}}
  </template>
}
