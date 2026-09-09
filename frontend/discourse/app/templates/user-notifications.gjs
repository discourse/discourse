import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.model.canLoadMore}}
    {{hideApplicationFooter}}
  {{/if}}

  {{bodyClass "user-notifications-page"}}

  <div class="user-navigation user-navigation-secondary">
    <DHorizontalOverflowNav @ariaLabel="User secondary - notifications">
      <DNavigationItem
        class="user-nav__notifications-all"
        @ariaCurrentContext="subNav"
        @route="userNotifications.index"
      >
        {{dIcon "bell"}}
        <span>{{i18n "user.filters.all"}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__notifications-responses"
        @ariaCurrentContext="subNav"
        @route="userNotifications.responses"
      >
        {{dIcon "reply"}}
        <span>{{i18n "user_action_groups.5"}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__notifications-likes"
        @ariaCurrentContext="subNav"
        @route="userNotifications.likesReceived"
      >
        {{dIcon "heart"}}
        <span>{{i18n "user_action_groups.2"}}</span>
      </DNavigationItem>

      {{#if @controller.siteSettings.enable_mentions}}
        <DNavigationItem
          class="user-nav__notifications-mentions"
          @ariaCurrentContext="subNav"
          @route="userNotifications.mentions"
        >
          {{dIcon "at"}}
          <span>{{i18n "user_action_groups.7"}}</span>
        </DNavigationItem>
      {{/if}}

      <DNavigationItem
        class="user-nav__notifications-edits"
        @ariaCurrentContext="subNav"
        @route="userNotifications.edits"
      >
        {{dIcon "pencil"}}
        <span>{{i18n "user_action_groups.11"}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__notifications-links"
        @ariaCurrentContext="subNav"
        @route="userNotifications.links"
      >
        {{dIcon "link"}}
        <span>{{i18n "user_action_groups.17"}}</span>
      </DNavigationItem>

      <PluginOutlet
        @connectorTagName="li"
        @name="user-notifications-bottom"
        @outletArgs={{lazyHash model=@controller.model}}
      />

    </DHorizontalOverflowNav>

    {{#if @controller.model.content}}
      <div class="navigation-controls">
        <DButton
          class="btn-default dismiss-notifications"
          @action={{@controller.resetNew}}
          @disabled={{@controller.allNotificationsRead}}
          @icon="check"
          @label="user.dismiss_notifications"
          @title="user.dismiss_notifications_tooltip"
        />
      </div>
    {{/if}}
  </div>

  <section class="user-content" id="user-content">
    <DLoadMore
      class="notification-history user-stream"
      @action={{@controller.loadMore}}
    >
      {{outlet}}
      <DConditionalLoadingSpinner
        @condition={{@controller.model.loadingMore}}
      />
    </DLoadMore>
  </section>
</template>
