import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { and } from "discourse/truth-helpers";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const UserNav = <template>
  <section class="user-navigation user-navigation-primary">
    <DHorizontalOverflowNav
      @ariaLabel="User primary"
      class="main-nav nav user-nav"
    >
      {{#unless @user.profile_hidden}}
        <DNavigationItem @route="user.summary" class="user-nav__summary">
          {{dIcon "user"}}
          <span>{{i18n "user.summary.title"}}</span>
        </DNavigationItem>

        {{#if @showActivityTab}}
          <DNavigationItem
            @route="userActivity"
            @ariaCurrentContext="parentNav"
            class="user-nav__activity"
          >
            {{dIcon "bars-staggered"}}
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
          {{dIcon "bell" class="glyph"}}
          <span>{{i18n "user.notifications"}}</span>
        </DNavigationItem>
      {{/if}}

      {{#if @showPrivateMessages}}
        <DNavigationItem
          @route="userPrivateMessages"
          @ariaCurrentContext="parentNav"
          class="user-nav__personal-messages"
        >
          {{dIcon "envelope"}}
          <span>{{i18n "user.private_messages"}}</span>
        </DNavigationItem>
      {{/if}}

      {{#if @canInviteToForum}}
        <DNavigationItem
          @route="userInvited"
          @ariaCurrentContext="parentNav"
          class="user-nav__invites"
        >
          {{dIcon "user-plus"}}
          <span>{{i18n "user.invited.title"}}</span>
        </DNavigationItem>
      {{/if}}

      {{#if @showBadges}}
        <DNavigationItem @route="user.badges" class="user-nav__badges">
          {{dIcon "certificate"}}
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
          {{dIcon "gear"}}
          <span>{{i18n "user.preferences.title"}}</span>
        </DNavigationItem>
      {{/if}}
      {{#if (and @isMobileView @isStaff)}}
        <li class="user-nav__admin">
          <a href={{@user.adminPath}}>
            {{dIcon "wrench"}}
            <span>{{i18n "admin.user.manage_user"}}</span>
          </a>
        </li>
      {{/if}}
    </DHorizontalOverflowNav>
  </section>
</template>;

export default UserNav;
