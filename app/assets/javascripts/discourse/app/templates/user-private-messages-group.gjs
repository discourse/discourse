import RouteTemplate from "ember-route-template";
import DNavigationItem from "discourse/components/d-navigation-item";
import MessagesSecondaryNav from "discourse/components/user-nav/messages-secondary-nav";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <MessagesSecondaryNav>

      <DNavigationItem
        @route="userPrivateMessages.group.index"
        @ariaCurrentContext="subNav"
        class="user-nav__messages-group-latest"
      >
        {{icon "envelope"}}
        <span>{{i18n "categories.latest"}}</span>
      </DNavigationItem>

      {{#if @controller.viewingSelf}}
        <DNavigationItem
          @route="userPrivateMessages.group.new"
          @ariaCurrentContext="subNav"
          class="user-nav__messages-group-new"
        >
          {{icon "circle-exclamation"}}
          <span>{{@controller.newLinkText}}</span>
        </DNavigationItem>

        <DNavigationItem
          @route="userPrivateMessages.group.unread"
          @ariaCurrentContext="subNav"
          class="user-nav__messages-group-unread"
        >
          {{icon "circle-plus"}}
          <span>{{@controller.unreadLinkText}}</span>
        </DNavigationItem>

        <DNavigationItem
          @route="userPrivateMessages.group.archive"
          @ariaCurrentContext="subNav"
          class="user-nav__messages-group-archive"
        >
          {{icon "box-archive"}}
          <span>{{i18n "user.messages.archive"}}</span>
        </DNavigationItem>
      {{/if}}
    </MessagesSecondaryNav>

    <div class="group-messages group-{{@controller.group.name}}">
      {{outlet}}
    </div>
  </template>
);
