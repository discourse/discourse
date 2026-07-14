import Component from "@glimmer/component";
import { service } from "@ember/service";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class RewindTab extends Component {
  @service rewind;

  get showNavTab() {
    return this.rewind.active && this.rewind.enabled;
  }

  <template>
    {{#if this.showNavTab}}
      <DNavigationItem
        @route="userActivity.rewind"
        @ariaCurrentContext="subNav"
        class="user-nav__activity-rewind"
      >
        {{dIcon "repeat"}}
        <span>{{i18n "discourse_rewind.title"}}</span>
      </DNavigationItem>
    {{/if}}
  </template>
}
