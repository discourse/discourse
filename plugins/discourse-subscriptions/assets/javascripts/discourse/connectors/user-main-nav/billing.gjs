import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class Billing extends Component {
  @service currentUser;

  get viewingSelf() {
    return (
      this.currentUser &&
      this.currentUser.username.toLowerCase() ===
        this.args.model.username.toLowerCase()
    );
  }

  <template>
    <li
      class={{dConcatClass
        "user-main-nav-outlet"
        "billing"
        (unless this.viewingSelf "hidden")
      }}
      ...attributes
    >
      <LinkTo @route="user.billing">
        {{dIcon "far-credit-card"}}
        <span>{{i18n "discourse_subscriptions.navigation.billing"}}</span>
      </LinkTo>
    </li>
  </template>
}
