import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{bodyClass "user-preferences-page"}}

  <div class="user-navigation user-navigation-secondary">
    <DHorizontalOverflowNav @ariaLabel="User secondary - preferences">
      <DNavigationItem
        class="user-nav__preferences-account"
        @ariaCurrentContext="subNav"
        @route="preferences.account"
      >
        {{dIcon "circle-user"}}
        <span>{{i18n "user.preferences_nav.account"}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__preferences-security"
        @ariaCurrentContext="subNav"
        @route="preferences.security"
      >
        {{dIcon "lock"}}
        <span>{{i18n "user.preferences_nav.security"}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__preferences-profile"
        @ariaCurrentContext="subNav"
        @route="preferences.profile"
      >
        {{dIcon "address-card"}}
        <span>{{i18n "user.preferences_nav.profile"}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__preferences-emails"
        @ariaCurrentContext="subNav"
        @route="preferences.emails"
      >
        {{dIcon "envelope"}}
        <span>{{i18n "user.preferences_nav.emails"}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__preferences-notifications"
        @ariaCurrentContext="subNav"
        @route="preferences.notifications"
      >
        {{dIcon "bell"}}
        <span>{{i18n "user.preferences_nav.notifications"}}</span>
      </DNavigationItem>

      {{#if @controller.model.can_change_tracking_preferences}}
        <DNavigationItem
          class="user-nav__preferences-tracking"
          @ariaCurrentContext="subNav"
          @route="preferences.tracking"
        >
          {{dIcon "plus"}}
          <span>{{i18n "user.preferences_nav.tracking"}}</span>
        </DNavigationItem>
      {{/if}}

      <DNavigationItem
        class="user-nav__preferences-users"
        @ariaCurrentContext="subNav"
        @route="preferences.users"
      >
        {{dIcon "users"}}
        <span>{{i18n "user.preferences_nav.users"}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__preferences-interface"
        @ariaCurrentContext="subNav"
        @route="preferences.interface"
      >
        {{dIcon "desktop"}}
        <span>{{i18n "user.preferences_nav.interface"}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__preferences-navigation-menu"
        @ariaCurrentContext="subNav"
        @route="preferences.navigation-menu"
      >
        {{dIcon "bars"}}
        <span>{{i18n "user.preferences_nav.navigation_menu"}}</span>
      </DNavigationItem>

      <DNavigationItem
        class="user-nav__preferences-calendar-subscriptions"
        @ariaCurrentContext="subNav"
        @route="preferences.calendar-subscriptions"
      >
        {{dIcon "calendar-days"}}
        <span>{{i18n "user.preferences_nav.calendar_subscriptions"}}</span>
      </DNavigationItem>

      <PluginOutlet
        @connectorTagName="div"
        @name="user-preferences-nav-under-interface"
        @outletArgs={{lazyHash model=@controller.model}}
      />
      <PluginOutlet
        @connectorTagName="li"
        @name="user-preferences-nav"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </DHorizontalOverflowNav>
  </div>

  <section class="user-content user-preferences" id="user-content">
    <span>
      <PluginOutlet
        @connectorTagName="div"
        @name="above-user-preferences"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </span>

    <form class="form-vertical">
      {{outlet}}
    </form>
  </section>
</template>
