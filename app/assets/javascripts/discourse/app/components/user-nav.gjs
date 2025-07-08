import { and } from "truth-helpers";
import DNavigationItem from "discourse/components/d-navigation-item";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

const UserNav = <template>
  <section class="user-navigation user-navigation-primary">
    <HorizontalOverflowNav
      @ariaLabel="User primary"
      class="main-nav nav user-nav"
    >
      {{#unless @user.profile_hidden}}
        <DNavigationItem @route="user.summary" class="user-nav__summary">
          {{icon "user"}}
          <span>{{i18n "user.summary.title"}}</span>
        </DNavigationItem>

        {{#if @showActivityTab}}
          <DNavigationItem
            @route="userActivity"
            @ariaCurrentContext="parentNav"
            class="user-nav__activity"
          >
            {{icon "bars-staggered"}}
            <span>{{i18n "user.activity_stream"}}</span>
          </DNavigationItem>
        {{/if}}
      {{/unless}}

      {{#if @showNotificationsTab}}
        <DNavigationItem
          @route="userNotifications"
          @ariaCurrentContext="parentNav"
          class="user-nav__notifications"
        >
          {{icon "bell" class="glyph"}}
          <span>{{i18n "user.notifications"}}</span>
        </DNavigationItem>
      {{/if}}

      {{#if @showPrivateMessages}}
        <DNavigationItem
          @route="userPrivateMessages"
          @ariaCurrentContext="parentNav"
          class="user-nav__personal-messages"
        >
          {{icon "envelope"}}
          <span>{{i18n "user.private_messages"}}</span>
        </DNavigationItem>
      {{/if}}

      {{#if @canInviteToForum}}
        <DNavigationItem
          @route="userInvited"
          @ariaCurrentContext="parentNav"
          class="user-nav__invites"
        >
          {{icon "user-plus"}}
          <span>{{i18n "user.invited.title"}}</span>
        </DNavigationItem>
      {{/if}}

      {{#if @showBadges}}
        <DNavigationItem @route="user.badges" class="user-nav__badges">
          {{icon "certificate"}}
          <span>{{i18n "badges.title"}}</span>
        </DNavigationItem>
      {{/if}}

      <PluginOutlet
        @name="user-main-nav"
        @connectorTagName="li"
        @outletArgs={{lazyHash model=@user}}
      />

      {{#if @user.can_edit}}
        <DNavigationItem
          @route="preferences"
          @ariaCurrentContext="parentNav"
          class="user-nav__preferences"
        >
          {{icon "gear"}}
          <span>{{i18n "user.preferences.title"}}</span>
        </DNavigationItem>
      {{/if}}
      {{#if (and @isMobileView @isStaff)}}
        <li class="user-nav__admin">
          <a href={{@user.adminPath}}>
            {{icon "wrench"}}
            <span>{{i18n "admin.user.manage_user"}}</span>
          </a>
        </li>
      {{/if}}
    </HorizontalOverflowNav>
  </section>
</template>;

export default UserNav;
