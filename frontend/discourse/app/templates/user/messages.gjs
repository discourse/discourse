import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import GroupNotificationsTracking from "discourse/components/group-notifications-tracking";
import PluginOutlet from "discourse/components/plugin-outlet";
import MessagesDropdown from "discourse/components/user-nav/messages-dropdown";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";

export default <template>
  {{bodyClass "user-messages-page"}}

  <PluginOutlet
    @name="user-messages-above-navigation"
    @outletArgs={{lazyHash model=@controller.model}}
  />

  <div class="user-navigation user-navigation-secondary">
    <ol class="category-breadcrumb">
      <li>
        <MessagesDropdown
          @content={{@controller.messagesDropdownContent}}
          @onChange={{@controller.onMessagesDropdownChange}}
          @value={{@controller.messagesDropdownValue}}
        />
      </li>
    </ol>

    <DHorizontalOverflowNav
      class="messages-nav"
      id="user-navigation-secondary__horizontal-nav"
      @ariaLabel="User secondary - messages"
    />

    <div class="navigation-controls">
      {{#if @controller.site.mobileView}}
        {{#if @controller.currentUser.admin}}
          <BulkSelectToggle
            @bulkSelectHelper={{@controller.bulkSelectHelper}}
          />
        {{/if}}
      {{/if}}

      {{#if @controller.isGroup}}
        <GroupNotificationsTracking
          @levelId={{@controller.group.group_user.notification_level}}
          @onChange={{@controller.changeGroupNotificationLevel}}
        />
      {{/if}}

      {{#if @controller.showNewPM}}
        <DButton
          class="btn-primary new-private-message"
          id="new-private-message-btn"
          @action={{routeAction "composePrivateMessage"}}
          @icon="envelope"
          @label="user.new_private_message"
        />
      {{/if}}
      <PluginOutlet
        @name="user-messages-controls-bottom"
        @outletArgs={{lazyHash showNewPM=@controller.showNewPM}}
      />
    </div>
  </div>

  <section class="user-content" id="user-content">
    {{outlet}}
  </section>
</template>
