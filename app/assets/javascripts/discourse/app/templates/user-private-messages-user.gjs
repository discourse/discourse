import RouteTemplate from 'ember-route-template';
import DNavigationItem from "discourse/components/d-navigation-item";
import MessagesSecondaryNav from "discourse/components/user-nav/messages-secondary-nav";
import dIcon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template>{{#if @controller.showWarningsWarning}}
  <div class="alert alert-info">{{htmlSafe (iN "admin.user.warnings_list_warning")}}</div>
{{/if}}

<MessagesSecondaryNav>
  <DNavigationItem @route="userPrivateMessages.user.index" @ariaCurrentContext="subNav" class="user-nav__messages-latest">
    {{dIcon "envelope"}}
    <span>{{iN "categories.latest"}}</span>
  </DNavigationItem>

  <DNavigationItem @route="userPrivateMessages.user.sent" @ariaCurrentContext="subNav" class="user-nav__messages-sent">
    {{dIcon "reply"}}
    <span>{{iN "user.messages.sent"}}</span>
  </DNavigationItem>

  {{#if @controller.viewingSelf}}
    <DNavigationItem @route="userPrivateMessages.user.new" @ariaCurrentContext="subNav" class="user-nav__messages-new">
      {{dIcon "circle-exclamation"}}
      <span>{{@controller.newLinkText}}</span>
    </DNavigationItem>

    <DNavigationItem @route="userPrivateMessages.user.unread" @ariaCurrentContext="subNav" class="user-nav__messages-unread">
      {{dIcon "circle-plus"}}
      <span>{{@controller.unreadLinkText}}</span>
    </DNavigationItem>

  {{/if}}

  <DNavigationItem @route="userPrivateMessages.user.archive" @ariaCurrentContext="subNav" class="user-nav__messages-archive">
    {{dIcon "box-archive"}}
    <span>{{iN "user.messages.archive"}}</span>
  </DNavigationItem>

</MessagesSecondaryNav>

{{outlet}}</template>);