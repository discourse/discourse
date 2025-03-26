import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import DNavigationItem from "discourse/components/d-navigation-item";
import MessagesSecondaryNav from "discourse/components/user-nav/messages-secondary-nav";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{#if @controller.showWarningsWarning}}
      <div class="alert alert-info">{{htmlSafe
          (i18n "admin.user.warnings_list_warning")
        }}</div>
    {{/if}}

    <MessagesSecondaryNav>
      <DNavigationItem
        @route="userPrivateMessages.user.index"
        @ariaCurrentContext="subNav"
        class="user-nav__messages-latest"
      >
        {{icon "envelope"}}
        <span>{{i18n "categories.latest"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="userPrivateMessages.user.sent"
        @ariaCurrentContext="subNav"
        class="user-nav__messages-sent"
      >
        {{icon "reply"}}
        <span>{{i18n "user.messages.sent"}}</span>
      </DNavigationItem>

      {{#if @controller.viewingSelf}}
        <DNavigationItem
          @route="userPrivateMessages.user.new"
          @ariaCurrentContext="subNav"
          class="user-nav__messages-new"
        >
          {{icon "circle-exclamation"}}
          <span>{{@controller.newLinkText}}</span>
        </DNavigationItem>

        <DNavigationItem
          @route="userPrivateMessages.user.unread"
          @ariaCurrentContext="subNav"
          class="user-nav__messages-unread"
        >
          {{icon "circle-plus"}}
          <span>{{@controller.unreadLinkText}}</span>
        </DNavigationItem>

      {{/if}}

      <DNavigationItem
        @route="userPrivateMessages.user.archive"
        @ariaCurrentContext="subNav"
        class="user-nav__messages-archive"
      >
        {{icon "box-archive"}}
        <span>{{i18n "user.messages.archive"}}</span>
      </DNavigationItem>

    </MessagesSecondaryNav>

    {{outlet}}
  </template>
);
