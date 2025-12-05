import Component from "@glimmer/component";
import { service } from "@ember/service";
import DNavigationItem from "discourse/components/d-navigation-item";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class RewindTab extends Component {
  @service currentUser;

  <template>
    {{#if this.currentUser.is_rewind_active}}
      <DNavigationItem
        @route="userActivity.rewind"
        @ariaCurrentContext="subNav"
        class="user-nav__activity-rewind"
      >
        {{icon "repeat"}}
        <span>{{i18n "discourse_rewind.title"}}</span>
      </DNavigationItem>
    {{/if}}
  </template>
}
