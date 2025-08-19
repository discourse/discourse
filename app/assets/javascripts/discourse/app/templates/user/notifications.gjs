import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DNavigationItem from "discourse/components/d-navigation-item";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import LoadMore from "discourse/components/load-more";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{#if @controller.model.canLoadMore}}
      {{hideApplicationFooter}}
    {{/if}}

    {{bodyClass "user-notifications-page"}}

    <div class="user-navigation user-navigation-secondary">
      <HorizontalOverflowNav @ariaLabel="User secondary - notifications">
        <DNavigationItem
          @route="userNotifications.index"
          @ariaCurrentContext="subNav"
          class="user-nav__notifications-all"
        >
          {{icon "bell"}}
          <span>{{i18n "user.filters.all"}}</span>
        </DNavigationItem>

        <DNavigationItem
          @route="userNotifications.responses"
          @ariaCurrentContext="subNav"
          class="user-nav__notifications-responses"
        >
          {{icon "reply"}}
          <span>{{i18n "user_action_groups.5"}}</span>
        </DNavigationItem>

        <DNavigationItem
          @route="userNotifications.likesReceived"
          @ariaCurrentContext="subNav"
          class="user-nav__notifications-likes"
        >
          {{icon "heart"}}
          <span>{{i18n "user_action_groups.2"}}</span>
        </DNavigationItem>

        {{#if @controller.siteSettings.enable_mentions}}
          <DNavigationItem
            @route="userNotifications.mentions"
            @ariaCurrentContext="subNav"
            class="user-nav__notifications-mentions"
          >
            {{icon "at"}}
            <span>{{i18n "user_action_groups.7"}}</span>
          </DNavigationItem>
        {{/if}}

        <DNavigationItem
          @route="userNotifications.edits"
          @ariaCurrentContext="subNav"
          class="user-nav__notifications-edits"
        >
          {{icon "pencil"}}
          <span>{{i18n "user_action_groups.11"}}</span>
        </DNavigationItem>

        <DNavigationItem
          @route="userNotifications.links"
          @ariaCurrentContext="subNav"
          class="user-nav__notifications-links"
        >
          {{icon "link"}}
          <span>{{i18n "user_action_groups.17"}}</span>
        </DNavigationItem>

        <PluginOutlet
          @name="user-notifications-bottom"
          @connectorTagName="li"
          @outletArgs={{lazyHash model=@controller.model}}
        />

      </HorizontalOverflowNav>

      {{#if @controller.model}}
        <div class="navigation-controls">
          <DButton
            @title="user.dismiss_notifications_tooltip"
            @action={{@controller.resetNew}}
            @label="user.dismiss_notifications"
            @icon="check"
            @disabled={{@controller.allNotificationsRead}}
            class="btn-default dismiss-notifications"
          />
        </div>
      {{/if}}
    </div>

    <section class="user-content" id="user-content">
      <LoadMore
        @action={{@controller.loadMore}}
        class="notification-history user-stream"
      >
        {{outlet}}
        <ConditionalLoadingSpinner
          @condition={{@controller.model.loadingMore}}
        />
      </LoadMore>
    </section>
  </template>
);
