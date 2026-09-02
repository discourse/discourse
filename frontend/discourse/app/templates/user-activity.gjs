import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { gt } from "discourse/truth-helpers";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{bodyClass "user-activity-page"}}
  <PluginOutlet @name="user-activity-navigation-wrapper">
    <div class="user-navigation user-navigation-secondary">
      <DHorizontalOverflowNav @ariaLabel="User secondary - activity">
        <DNavigationItem
          class="user-nav__activity-all"
          @ariaCurrentContext="subNav"
          @route="userActivity.index"
        >
          {{dIcon "bars-staggered"}}
          <span>{{i18n "user.filters.all"}}</span>
        </DNavigationItem>

        <DNavigationItem
          class="user-nav__activity-topics"
          @ariaCurrentContext="subNav"
          @route="userActivity.topics"
        >
          {{dIcon "list-ul"}}
          <span>{{i18n "user_action_groups.4"}}</span>
        </DNavigationItem>
        <DNavigationItem
          class="user-nav__activity-replies"
          @ariaCurrentContext="subNav"
          @route="userActivity.replies"
        >
          {{dIcon "reply"}}
          <span>{{i18n "user_action_groups.5"}}</span>
        </DNavigationItem>

        {{#if @controller.user.showRead}}
          <DNavigationItem
            class="user-nav__activity-read"
            title={{i18n "user.read_help"}}
            @ariaCurrentContext="subNav"
            @route="userActivity.read"
          >
            {{dIcon "clock-rotate-left"}}
            <span>{{i18n "user.read"}}</span>
          </DNavigationItem>
        {{/if}}

        {{#if @controller.user.showDrafts}}
          <DNavigationItem
            class="user-nav__activity-drafts"
            @ariaCurrentContext="subNav"
            @route="userActivity.drafts"
          >
            {{dIcon "pencil"}}
            <span>{{@controller.draftLabel}}</span>
          </DNavigationItem>
        {{/if}}

        {{#if (gt @controller.model.pending_posts_count 0)}}
          <DNavigationItem
            class="user-nav__activity-pending"
            @ariaCurrentContext="subNav"
            @route="userActivity.pending"
          >
            {{dIcon "clock"}}
            <span>{{@controller.pendingLabel}}</span>
          </DNavigationItem>
        {{/if}}

        <DNavigationItem
          class="user-nav__activity-likes"
          @ariaCurrentContext="subNav"
          @route="userActivity.likesGiven"
        >
          {{dIcon "heart"}}
          <span>{{i18n "user_action_groups.1"}}</span>
        </DNavigationItem>

        {{#if @controller.user.showBookmarks}}
          <DNavigationItem
            class="user-nav__activity-bookmarks"
            @ariaCurrentContext="subNav"
            @route="userActivity.bookmarks"
          >
            {{dIcon "bookmark"}}
            <span>{{i18n "user_action_groups.3"}}</span>
          </DNavigationItem>
        {{/if}}

        <PluginOutlet
          @connectorTagName="li"
          @name="user-activity-bottom"
          @outletArgs={{lazyHash model=@controller.model}}
        />
      </DHorizontalOverflowNav>
    </div>
  </PluginOutlet>
  <section class="user-content" id="user-content">
    {{outlet}}
  </section>
</template>
