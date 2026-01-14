/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import {
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("li")
@classNames("user-main-nav-outlet", "billing")
@classNameBindings("viewingSelf::hidden")
export default class Billing extends Component {
  @service currentUser;

  get viewingSelf() {
    return (
      this.currentUser &&
      this.currentUser.username.toLowerCase() ===
        this.model.username.toLowerCase()
    );
  }

  <template>
    <LinkTo @route="user.billing">
      {{icon "far-credit-card"}}
      <span>{{i18n "discourse_subscriptions.navigation.billing"}}</span>
    </LinkTo>
  </template>
}
