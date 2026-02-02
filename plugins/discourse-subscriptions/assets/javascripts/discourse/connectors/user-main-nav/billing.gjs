/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("")
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
    <li
      class={{concatClass
        "user-main-nav-outlet"
        "billing"
        (unless this.viewingSelf "hidden")
      }}
      ...attributes
    >
      <LinkTo @route="user.billing">
        {{icon "far-credit-card"}}
        <span>{{i18n "discourse_subscriptions.navigation.billing"}}</span>
      </LinkTo>
    </li>
  </template>
}
