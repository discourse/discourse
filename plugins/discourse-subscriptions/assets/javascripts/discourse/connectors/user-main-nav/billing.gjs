/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { classNames, tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";

@tagName("li")
@classNames("user-main-nav-outlet", "billing")
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
    {{#if this.viewingSelf}}
      <LinkTo @route="user.billing">
        {{icon "far-credit-card"}}
      </LinkTo>
    {{/if}}
  </template>
}
