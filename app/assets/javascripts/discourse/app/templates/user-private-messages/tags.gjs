import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import MessagesSecondaryNav from "discourse/components/user-nav/messages-secondary-nav";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <MessagesSecondaryNav>
      <li class="tags">
        <LinkTo @route="userPrivateMessages.tags.index">
          {{icon "tag"}}
          <span>{{i18n "user.messages.all_tags"}}</span>
        </LinkTo>
      </li>

      {{#if @controller.tagName}}
        <li class="archive">
          <LinkTo
            @route="userPrivateMessages.tags.show"
            @model={{@controller.tagName}}
          >
            {{@controller.tagName}}
          </LinkTo>
        </li>
      {{/if}}
    </MessagesSecondaryNav>

    {{outlet}}
  </template>
);
