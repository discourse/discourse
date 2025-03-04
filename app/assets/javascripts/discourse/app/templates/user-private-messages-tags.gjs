import RouteTemplate from 'ember-route-template'
import MessagesSecondaryNav from "discourse/components/user-nav/messages-secondary-nav";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse/helpers/d-icon";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template><MessagesSecondaryNav>
  <li class="tags">
    <LinkTo @route="userPrivateMessages.tags.index">
      {{dIcon "tag"}}
      <span>{{iN "user.messages.all_tags"}}</span>
    </LinkTo>
  </li>

  {{#if @controller.tagName}}
    <li class="archive">
      <LinkTo @route="userPrivateMessages.tags.show" @model={{@controller.tagName}}>
        {{@controller.tagName}}
      </LinkTo>
    </li>
  {{/if}}
</MessagesSecondaryNav>

{{outlet}}</template>)