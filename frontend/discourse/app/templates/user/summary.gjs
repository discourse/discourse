import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserSummaryCategorySearch from "discourse/components/user-summary-category-search";
import UserSummarySection from "discourse/components/user-summary-section";
import UserSummaryTopic from "discourse/components/user-summary-topic";
import UserSummaryTopicsList from "discourse/components/user-summary-topics-list";
import UserSummaryUser from "discourse/components/user-summary-user";
import UserSummaryUsersList from "discourse/components/user-summary-users-list";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import shortenUrl from "discourse/helpers/shorten-url";
import DBadgeCard from "discourse/ui-kit/d-badge-card";
import DUserStat from "discourse/ui-kit/d-user-stat";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import { i18n } from "discourse-i18n";

export default <template>
  {{bodyClass "user-summary-page"}}

  <div class="user-content" id="user-content">
    <PluginOutlet
      @name="above-user-summary-stats"
      @outletArgs={{lazyHash model=@controller.model user=@controller.user}}
    />
    {{#if @controller.model.can_see_summary_stats}}
      <div class="top-section stats-section">
        <h3 class="stats-title">{{i18n "user.summary.stats"}}</h3>
        <ul>
          <li class="stats-days-visited">
            <DUserStat
              @label="user.summary.days_visited"
              @value={{@controller.model.days_visited}}
            />
          </li>
          <li class="stats-time-read">
            <DUserStat
              @label="user.summary.time_read"
              @rawTitle={{i18n
                "user.summary.time_read_title"
                duration=@controller.timeReadMedium
              }}
              @type="string"
              @value={{@controller.timeRead}}
            />
          </li>
          {{#if @controller.showRecentTimeRead}}
            <li class="stats-recent-read">
              <DUserStat
                @label="user.summary.recent_time_read"
                @rawTitle={{i18n
                  "user.summary.recent_time_read_title"
                  duration=@controller.recentTimeReadMedium
                }}
                @type="string"
                @value={{@controller.recentTimeRead}}
              />
            </li>
          {{/if}}
          <li class="stats-topics-entered">
            <DUserStat
              @label="user.summary.topics_entered"
              @value={{@controller.model.topics_entered}}
            />
          </li>
          <li class="stats-posts-read">
            <DUserStat
              @label="user.summary.posts_read"
              @value={{@controller.model.posts_read_count}}
            />
          </li>
          {{#if @controller.model.can_see_user_actions}}
            <li class="stats-likes-given linked-stat">
              <LinkTo @route="userActivity.likesGiven">
                <DUserStat
                  @icon="heart"
                  @label="user.summary.likes_given"
                  @value={{@controller.model.likes_given}}
                />
              </LinkTo>
            </li>
          {{else}}
            <li class="stats-likes-given">
              <DUserStat
                @icon="heart"
                @label="user.summary.likes_given"
                @value={{@controller.model.likes_given}}
              />
            </li>
          {{/if}}
          <li class="stats-likes-received">
            <DUserStat
              @icon="heart"
              @label="user.summary.likes_received"
              @value={{@controller.model.likes_received}}
            />
          </li>
          {{#if @controller.model.bookmark_count}}
            {{#if @controller.model.can_see_user_actions}}
              <li class="stats-bookmark-count linked-stat">
                <LinkTo @route="userActivity.bookmarks">
                  <DUserStat
                    @label="user.summary.bookmark_count"
                    @value={{@controller.model.bookmark_count}}
                  />
                </LinkTo>
              </li>
            {{else}}
              <li class="stats-bookmark-count">
                <DUserStat
                  @label="user.summary.bookmark_count"
                  @value={{@controller.model.bookmark_count}}
                />
              </li>
            {{/if}}
          {{/if}}
          {{#if @controller.model.can_see_user_actions}}
            <li class="stats-topic-count linked-stat">
              <LinkTo @route="userActivity.topics">
                <DUserStat
                  @label="user.summary.topic_count"
                  @value={{@controller.model.topic_count}}
                />
              </LinkTo>
            </li>
          {{else}}
            <li class="stats-topic-count">
              <DUserStat
                @label="user.summary.topic_count"
                @value={{@controller.model.topic_count}}
              />
            </li>
          {{/if}}
          {{#if @controller.model.can_see_user_actions}}
            <li class="stats-post-count linked-stat">
              <LinkTo @route="userActivity.replies">
                <DUserStat
                  @label="user.summary.post_count"
                  @value={{@controller.model.post_count}}
                />
              </LinkTo>
            </li>
          {{else}}
            <li class="stats-post-count">
              <DUserStat
                @label="user.summary.post_count"
                @value={{@controller.model.post_count}}
              />
            </li>
          {{/if}}
          <PluginOutlet
            @connectorTagName="li"
            @name="user-summary-stat"
            @outletArgs={{lazyHash
              model=@controller.model
              user=@controller.user
            }}
          />
        </ul>
      </div>
    {{/if}}

    <PluginOutlet
      @name="below-user-summary-stats"
      @outletArgs={{lazyHash model=@controller.model user=@controller.user}}
    />

    <div class="top-section replies-and-topics-section">
      <UserSummarySection
        class="replies-section pull-left"
        @title="top_replies"
      >
        <UserSummaryTopicsList
          @items={{@controller.model.replies}}
          @type="replies"
          @user={{@controller.user}}
          as |reply|
        >
          <UserSummaryTopic
            @createdAt={{reply.createdAt}}
            @likes={{reply.like_count}}
            @topic={{reply.topic}}
            @url={{reply.url}}
          />
        </UserSummaryTopicsList>
      </UserSummarySection>

      <UserSummarySection class="topics-section pull-right" @title="top_topics">
        <UserSummaryTopicsList
          @items={{@controller.model.topics}}
          @type="topics"
          @user={{@controller.user}}
          as |topic|
        >
          <UserSummaryTopic
            @createdAt={{topic.created_at}}
            @likes={{topic.like_count}}
            @topic={{topic}}
            @url={{topic.url}}
          />
        </UserSummaryTopicsList>
      </UserSummarySection>
    </div>

    <div class="top-section links-and-replied-to-section">
      <UserSummarySection class="links-section pull-left" @title="top_links">
        {{#if @controller.model.links.length}}
          <ul>
            {{#each @controller.model.links as |link|}}
              <li>
                {{! eslint-disable ember/template-link-rel-noopener }}
                <a
                  aria-label={{i18n "topic_map.clicks" count=link.clicks}}
                  class="domain"
                  data-clicks={{link.clicks}}
                  href={{link.url}}
                  rel="noopener {{unless
                    @controller.user.removeNoFollow
                    'nofollow ugc'
                  }}"
                  target="_blank"
                  title={{link.title}}
                >
                  {{shortenUrl link.url}}
                </a>
                {{! eslint-enable ember/template-link-rel-noopener }}
                <br />

                <a href={{link.post_url}}>
                  {{trustHTML link.topic.fancyTitle}}
                </a>
              </li>
            {{/each}}
          </ul>
        {{else}}
          <p>{{i18n "user.summary.no_links"}}</p>
        {{/if}}
      </UserSummarySection>

      <UserSummarySection
        class="summary-user-list replied-section pull-right"
        @title="most_replied_to_users"
      >
        <UserSummaryUsersList
          @none="no_replies"
          @users={{@controller.model.most_replied_to_users}}
          as |user|
        >
          <UserSummaryUser @countClass="replies" @icon="reply" @user={{user}} />
        </UserSummaryUsersList>
      </UserSummarySection>
    </div>

    <div class="top-section most-liked-section">
      <UserSummarySection
        class="summary-user-list liked-by-section pull-left"
        @title="most_liked_by"
      >
        <UserSummaryUsersList
          @none="no_likes"
          @users={{@controller.model.most_liked_by_users}}
          as |user|
        >
          <UserSummaryUser @countClass="likes" @icon="heart" @user={{user}} />
        </UserSummaryUsersList>
      </UserSummarySection>

      <UserSummarySection
        class="summary-user-list liked-section pull-right"
        @title="most_liked_users"
      >
        <UserSummaryUsersList
          @none="no_likes"
          @users={{@controller.model.most_liked_users}}
          as |user|
        >
          <UserSummaryUser @countClass="likes" @icon="heart" @user={{user}} />
        </UserSummaryUsersList>
      </UserSummarySection>
    </div>

    {{#if @controller.model.top_categories.length}}
      <div class="top-section top-categories-section">
        <UserSummarySection
          class="summary-category-list pull-left"
          @title="top_categories"
        >
          <table>
            <thead>
              <th class="category-link"></th>
              <th class="topic-count">{{i18n "user.summary.topics"}}</th>
              <th class="reply-count">{{i18n "user.summary.replies"}}</th>
            </thead>
            <tbody>
              {{#each @controller.model.top_categories as |category|}}
                <tr>
                  <PluginOutlet
                    @name="user-summary-top-category-row"
                    @outletArgs={{lazyHash
                      category=category
                      user=@controller.user
                    }}
                  >
                    <td class="category-link">
                      {{dCategoryLink
                        category
                        allowUncategorized="true"
                        hideParent=false
                      }}
                    </td>
                    <td class="topic-count">
                      <UserSummaryCategorySearch
                        @category={{category}}
                        @count={{category.topic_count}}
                        @searchOnlyFirstPosts={{true}}
                        @user={{@controller.user}}
                      />
                    </td>
                    <td class="reply-count">
                      <UserSummaryCategorySearch
                        @category={{category}}
                        @count={{category.post_count}}
                        @searchOnlyFirstPosts={{false}}
                        @user={{@controller.user}}
                      />
                    </td>
                  </PluginOutlet>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </UserSummarySection>
      </div>
    {{/if}}

    {{#if @controller.siteSettings.enable_badges}}
      <div class="top-section badges-section">
        <h3 class="stats-title">{{i18n "user.summary.top_badges"}}</h3>

        {{#if @controller.model.badges}}
          <div class="badge-group-list">
            {{#each @controller.model.badges as |badge|}}
              <DBadgeCard
                @badge={{badge}}
                @count={{badge.count}}
                @username={{@controller.user.username_lower}}
              />
            {{/each}}
            <PluginOutlet
              @name="after-user-summary-badges"
              @outletArgs={{lazyHash
                model=@controller.model
                user=@controller.user
              }}
            />
          </div>
        {{else}}
          <p>{{i18n "user.summary.no_badges"}}</p>
        {{/if}}

        {{#if @controller.moreBadges}}
          <LinkTo class="more" @model={{@controller.user}} @route="user.badges">
            {{i18n "user.summary.more_badges"}}
          </LinkTo>
        {{/if}}
      </div>
    {{/if}}
  </div>
</template>
