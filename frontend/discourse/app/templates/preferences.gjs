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
        @route="preferences.account"
        @ariaCurrentContext="subNav"
        class="user-nav__preferences-account"
      >
        {{dIcon "circle-user"}}
        <span>{{i18n "user.preferences_nav.account"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="preferences.security"
        @ariaCurrentContext="subNav"
        class="user-nav__preferences-security"
      >
        {{dIcon "lock"}}
        <span>{{i18n "user.preferences_nav.security"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="preferences.profile"
        @ariaCurrentContext="subNav"
        class="user-nav__preferences-profile"
      >
        {{dIcon "address-card"}}
        <span>{{i18n "user.preferences_nav.profile"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="preferences.emails"
        @ariaCurrentContext="subNav"
        class="user-nav__preferences-emails"
      >
        {{dIcon "envelope"}}
        <span>{{i18n "user.preferences_nav.emails"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="preferences.notifications"
        @ariaCurrentContext="subNav"
        class="user-nav__preferences-notifications"
      >
        {{dIcon "bell"}}
        <span>{{i18n "user.preferences_nav.notifications"}}</span>
      </DNavigationItem>

      {{#if @controller.model.can_change_tracking_preferences}}
        <DNavigationItem
          @route="preferences.tracking"
          @ariaCurrentContext="subNav"
          class="user-nav__preferences-tracking"
        >
          {{dIcon "plus"}}
          <span>{{i18n "user.preferences_nav.tracking"}}</span>
        </DNavigationItem>
      {{/if}}

      <DNavigationItem
        @route="preferences.users"
        @ariaCurrentContext="subNav"
        class="user-nav__preferences-users"
      >
        {{dIcon "users"}}
        <span>{{i18n "user.preferences_nav.users"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="preferences.interface"
        @ariaCurrentContext="subNav"
        class="user-nav__preferences-interface"
      >
        {{dIcon "desktop"}}
        <span>{{i18n "user.preferences_nav.interface"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="preferences.navigation-menu"
        @ariaCurrentContext="subNav"
        class="user-nav__preferences-navigation-menu"
      >
        {{dIcon "bars"}}
        <span>{{i18n "user.preferences_nav.navigation_menu"}}</span>
      </DNavigationItem>

      <DNavigationItem
        @route="preferences.calendar-subscriptions"
        @ariaCurrentContext="subNav"
        class="user-nav__preferences-calendar-subscriptions"
      >
        {{dIcon "calendar-days"}}
        <span>{{i18n "user.preferences_nav.calendar_subscriptions"}}</span>
      </DNavigationItem>

      <PluginOutlet
        @name="user-preferences-nav-under-interface"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model}}
      />
      <PluginOutlet
        @name="user-preferences-nav"
        @connectorTagName="li"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </DHorizontalOverflowNav>
  </div>

  <section class="user-content user-preferences" id="user-content">
    <span>
      <PluginOutlet
        @name="above-user-preferences"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </span>

    <form class="form-vertical">
      {{outlet}}
    </form>
  </section>
</template>
