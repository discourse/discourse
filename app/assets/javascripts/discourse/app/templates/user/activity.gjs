import RouteTemplate from "ember-route-template";
import { gt } from "truth-helpers";
import DNavigationItem from "discourse/components/d-navigation-item";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{bodyClass "user-activity-page"}}
    <PluginOutlet @name="user-activity-navigation-wrapper">
      <div class="user-navigation user-navigation-secondary">
        <HorizontalOverflowNav @ariaLabel="User secondary - activity">
          <DNavigationItem
            @route="userActivity.index"
            @ariaCurrentContext="subNav"
            class="user-nav__activity-all"
          >
            {{icon "bars-staggered"}}
            <span>{{i18n "user.filters.all"}}</span>
          </DNavigationItem>

          <DNavigationItem
            @route="userActivity.topics"
            @ariaCurrentContext="subNav"
            class="user-nav__activity-topics"
          >
            {{icon "list-ul"}}
            <span>{{i18n "user_action_groups.4"}}</span>
          </DNavigationItem>
          <DNavigationItem
            @route="userActivity.replies"
            @ariaCurrentContext="subNav"
            class="user-nav__activity-replies"
          >
            {{icon "reply"}}
            <span>{{i18n "user_action_groups.5"}}</span>
          </DNavigationItem>

          {{#if @controller.user.showRead}}
            <DNavigationItem
              @route="userActivity.read"
              @ariaCurrentContext="subNav"
              class="user-nav__activity-read"
              title={{i18n "user.read_help"}}
            >
              {{icon "clock-rotate-left"}}
              <span>{{i18n "user.read"}}</span>
            </DNavigationItem>
          {{/if}}

          {{#if @controller.user.showDrafts}}
            <DNavigationItem
              @route="userActivity.drafts"
              @ariaCurrentContext="subNav"
              class="user-nav__activity-drafts"
            >
              {{icon "pencil"}}
              <span>{{@controller.draftLabel}}</span>
            </DNavigationItem>
          {{/if}}

          {{#if (gt @controller.model.pending_posts_count 0)}}
            <DNavigationItem
              @route="userActivity.pending"
              @ariaCurrentContext="subNav"
              class="user-nav__activity-pending"
            >
              {{icon "clock"}}
              <span>{{@controller.pendingLabel}}</span>
            </DNavigationItem>
          {{/if}}

          <DNavigationItem
            @route="userActivity.likesGiven"
            @ariaCurrentContext="subNav"
            class="user-nav__activity-likes"
          >
            {{icon "heart"}}
            <span>{{i18n "user_action_groups.1"}}</span>
          </DNavigationItem>

          {{#if @controller.user.showBookmarks}}
            <DNavigationItem
              @route="userActivity.bookmarks"
              @ariaCurrentContext="subNav"
              class="user-nav__activity-bookmarks"
            >
              {{icon "bookmark"}}
              <span>{{i18n "user_action_groups.3"}}</span>
            </DNavigationItem>
          {{/if}}

          <PluginOutlet
            @name="user-activity-bottom"
            @connectorTagName="li"
            @outletArgs={{lazyHash model=@controller.model}}
          />
        </HorizontalOverflowNav>
      </div>
    </PluginOutlet>
    <section class="user-content" id="user-content">
      {{outlet}}
    </section>
  </template>
);
