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
        @route="userNotifications.index"
        @ariaCurrentContext="subNav"
        class="user-nav__notifications-all"
      >
        {{dIcon "bell"}}
        <span>{{i18n "user.filters.all"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="userNotifications.responses"
        @ariaCurrentContext="subNav"
        class="user-nav__notifications-responses"
      >
        {{dIcon "reply"}}
        <span>{{i18n "user_action_groups.5"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="userNotifications.likesReceived"
        @ariaCurrentContext="subNav"
        class="user-nav__notifications-likes"
      >
        {{dIcon "heart"}}
        <span>{{i18n "user_action_groups.2"}}</span>
      </DNavigationItem>

      {{#if @controller.siteSettings.enable_mentions}}
        <DNavigationItem
          @route="userNotifications.mentions"
          @ariaCurrentContext="subNav"
          class="user-nav__notifications-mentions"
        >
          {{dIcon "at"}}
          <span>{{i18n "user_action_groups.7"}}</span>
        </DNavigationItem>
      {{/if}}

      <DNavigationItem
        @route="userNotifications.edits"
        @ariaCurrentContext="subNav"
        class="user-nav__notifications-edits"
      >
        {{dIcon "pencil"}}
        <span>{{i18n "user_action_groups.11"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="userNotifications.links"
        @ariaCurrentContext="subNav"
        class="user-nav__notifications-links"
      >
        {{dIcon "link"}}
        <span>{{i18n "user_action_groups.17"}}</span>
      </DNavigationItem>

      <PluginOutlet
        @name="user-notifications-bottom"
        @connectorTagName="li"
        @outletArgs={{lazyHash model=@controller.model}}
      />

    </DHorizontalOverflowNav>

    {{#if @controller.model.content}}
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
    <DLoadMore
      @action={{@controller.loadMore}}
      class="notification-history user-stream"
    >
      {{outlet}}
      <DConditionalLoadingSpinner
        @condition={{@controller.model.loadingMore}}
      />
    </DLoadMore>
  </section>
</template>
