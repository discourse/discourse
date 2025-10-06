import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import MessagesSecondaryNav from "discourse/components/user-nav/messages-secondary-nav";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <MessagesSecondaryNav>
      <li class="messages-assigned-latest">
        <LinkTo @route="userPrivateMessages.assigned.index">
          {{icon "envelope"}}
          <span>{{i18n "categories.latest"}}</span>
        </LinkTo>
      </li>
    </MessagesSecondaryNav>

    {{outlet}}
  </template>
);
