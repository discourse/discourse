import RouteTemplate from "ember-route-template";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import DButton from "discourse/components/d-button";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import PluginOutlet from "discourse/components/plugin-outlet";
import MessagesDropdown from "discourse/components/user-nav/messages-dropdown";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";

export default RouteTemplate(
  <template>
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
            @value={{@controller.messagesDropdownValue}}
            @onChange={{@controller.onMessagesDropdownChange}}
          />
        </li>
      </ol>

      <HorizontalOverflowNav
        @ariaLabel="User secondary - messages"
        id="user-navigation-secondary__horizontal-nav"
        class="messages-nav"
      />

      <div class="navigation-controls">
        {{#if @controller.site.mobileView}}
          {{#if @controller.currentUser.admin}}
            <BulkSelectToggle
              @bulkSelectHelper={{@controller.bulkSelectHelper}}
            />
          {{/if}}
        {{/if}}

        <span id="navigation-controls__button"></span>

        {{#if @controller.showNewPM}}
          <DButton
            @action={{routeAction "composePrivateMessage"}}
            @icon="envelope"
            @label="user.new_private_message"
            class="btn-primary new-private-message"
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
);
