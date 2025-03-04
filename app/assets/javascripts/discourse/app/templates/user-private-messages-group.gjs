import RouteTemplate from "ember-route-template";
import DNavigationItem from "discourse/components/d-navigation-item";
import GroupNotificationsTracking from "discourse/components/group-notifications-tracking";
import MessagesSecondaryNav from "discourse/components/user-nav/messages-secondary-nav";
import dIcon from "discourse/helpers/d-icon";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template>
  <MessagesSecondaryNav>

    <DNavigationItem
      @route="userPrivateMessages.group.index"
      @ariaCurrentContext="subNav"
      class="user-nav__messages-group-latest"
    >
      {{dIcon "envelope"}}
      <span>{{iN "categories.latest"}}</span>
    </DNavigationItem>

    {{#if @controller.viewingSelf}}
      <DNavigationItem
        @route="userPrivateMessages.group.new"
        @ariaCurrentContext="subNav"
        class="user-nav__messages-group-new"
      >
        {{dIcon "circle-exclamation"}}
        <span>{{@controller.newLinkText}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="userPrivateMessages.group.unread"
        @ariaCurrentContext="subNav"
        class="user-nav__messages-group-unread"
      >
        {{dIcon "circle-plus"}}
        <span>{{@controller.unreadLinkText}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="userPrivateMessages.group.archive"
        @ariaCurrentContext="subNav"
        class="user-nav__messages-group-archive"
      >
        {{dIcon "box-archive"}}
        <span>{{iN "user.messages.archive"}}</span>
      </DNavigationItem>
    {{/if}}
  </MessagesSecondaryNav>

  {{#in-element @controller.navigationControlsButton}}
    <GroupNotificationsTracking
      @levelId={{@controller.group.group_user.notification_level}}
      @onChange={{@controller.changeGroupNotificationLevel}}
    />
  {{/in-element}}

  <div class="group-messages group-{{@controller.group.name}}">
    {{outlet}}
  </div>
</template>);
