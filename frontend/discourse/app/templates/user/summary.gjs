import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import BadgeCard from "discourse/components/badge-card";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserStat from "discourse/components/user-stat";
import UserSummaryCategorySearch from "discourse/components/user-summary-category-search";
import UserSummarySection from "discourse/components/user-summary-section";
import UserSummaryTopic from "discourse/components/user-summary-topic";
import UserSummaryTopicsList from "discourse/components/user-summary-topics-list";
import UserSummaryUser from "discourse/components/user-summary-user";
import UserSummaryUsersList from "discourse/components/user-summary-users-list";
import bodyClass from "discourse/helpers/body-class";
import categoryLink from "discourse/helpers/category-link";
import lazyHash from "discourse/helpers/lazy-hash";
import shortenUrl from "discourse/helpers/shorten-url";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
              <UserStat
                @value={{@controller.model.days_visited}}
                @label="user.summary.days_visited"
              />
            </li>
            <li class="stats-time-read">
              <UserStat
                @value={{@controller.timeRead}}
                @label="user.summary.time_read"
                @rawTitle={{i18n
                  "user.summary.time_read_title"
                  duration=@controller.timeReadMedium
                }}
                @type="string"
              />
            </li>
            {{#if @controller.showRecentTimeRead}}
              <li class="stats-recent-read">
                <UserStat
                  @value={{@controller.recentTimeRead}}
                  @label="user.summary.recent_time_read"
                  @rawTitle={{i18n
                    "user.summary.recent_time_read_title"
                    duration=@controller.recentTimeReadMedium
                  }}
                  @type="string"
                />
              </li>
            {{/if}}
            <li class="stats-topics-entered">
              <UserStat
                @value={{@controller.model.topics_entered}}
                @label="user.summary.topics_entered"
              />
            </li>
            <li class="stats-posts-read">
              <UserStat
                @value={{@controller.model.posts_read_count}}
                @label="user.summary.posts_read"
              />
            </li>
            {{#if @controller.model.can_see_user_actions}}
              <li class="stats-likes-given linked-stat">
                <LinkTo @route="userActivity.likesGiven">
                  <UserStat
                    @value={{@controller.model.likes_given}}
                    @icon="heart"
                    @label="user.summary.likes_given"
                  />
                </LinkTo>
              </li>
            {{else}}
              <li class="stats-likes-given">
                <UserStat
                  @value={{@controller.model.likes_given}}
                  @icon="heart"
                  @label="user.summary.likes_given"
                />
              </li>
            {{/if}}
            <li class="stats-likes-received">
              <UserStat
                @value={{@controller.model.likes_received}}
                @icon="heart"
                @label="user.summary.likes_received"
              />
            </li>
            {{#if @controller.model.bookmark_count}}
              {{#if @controller.model.can_see_user_actions}}
                <li class="stats-bookmark-count linked-stat">
                  <LinkTo @route="userActivity.bookmarks">
                    <UserStat
                      @value={{@controller.model.bookmark_count}}
                      @label="user.summary.bookmark_count"
                    />
                  </LinkTo>
                </li>
              {{else}}
                <li class="stats-bookmark-count">
                  <UserStat
                    @value={{@controller.model.bookmark_count}}
                    @label="user.summary.bookmark_count"
                  />
                </li>
              {{/if}}
            {{/if}}
            {{#if @controller.model.can_see_user_actions}}
              <li class="stats-topic-count linked-stat">
                <LinkTo @route="userActivity.topics">
                  <UserStat
                    @value={{@controller.model.topic_count}}
                    @label="user.summary.topic_count"
                  />
                </LinkTo>
              </li>
            {{else}}
              <li class="stats-topic-count">
                <UserStat
                  @value={{@controller.model.topic_count}}
                  @label="user.summary.topic_count"
                />
              </li>
            {{/if}}
            {{#if @controller.model.can_see_user_actions}}
              <li class="stats-post-count linked-stat">
                <LinkTo @route="userActivity.replies">
                  <UserStat
                    @value={{@controller.model.post_count}}
                    @label="user.summary.post_count"
                  />
                </LinkTo>
              </li>
            {{else}}
              <li class="stats-post-count">
                <UserStat
                  @value={{@controller.model.post_count}}
                  @label="user.summary.post_count"
                />
              </li>
            {{/if}}
            <PluginOutlet
              @name="user-summary-stat"
              @connectorTagName="li"
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
          @title="top_replies"
          class="replies-section pull-left"
        >
          <UserSummaryTopicsList
            @type="replies"
            @items={{@controller.model.replies}}
            @user={{@controller.user}}
            as |reply|
          >
            <UserSummaryTopic
              @createdAt={{reply.createdAt}}
              @topic={{reply.topic}}
              @likes={{reply.like_count}}
              @url={{reply.url}}
            />
          </UserSummaryTopicsList>
        </UserSummarySection>

        <UserSummarySection
          @title="top_topics"
          class="topics-section pull-right"
        >
          <UserSummaryTopicsList
            @type="topics"
            @items={{@controller.model.topics}}
            @user={{@controller.user}}
            as |topic|
          >
            <UserSummaryTopic
              @createdAt={{topic.created_at}}
              @topic={{topic}}
              @likes={{topic.like_count}}
              @url={{topic.url}}
            />
          </UserSummaryTopicsList>
        </UserSummarySection>
      </div>

      <div class="top-section links-and-replied-to-section">
        <UserSummarySection @title="top_links" class="links-section pull-left">
          {{#if @controller.model.links.length}}
            <ul>
              {{#each @controller.model.links as |link|}}
                <li>
                  {{! template-lint-disable link-rel-noopener }}
                  <a
                    class="domain"
                    href={{link.url}}
                    title={{link.title}}
                    rel="noopener {{unless
                      @controller.user.removeNoFollow
                      'nofollow ugc'
                    }}"
                    target="_blank"
                    data-clicks={{link.clicks}}
                    aria-label={{i18n "topic_map.clicks" count=link.clicks}}
                  >
                    {{shortenUrl link.url}}
                  </a>
                  {{! template-lint-enable link-rel-noopener }}
                  <br />

                  <a href={{link.post_url}}>
                    {{htmlSafe link.topic.fancyTitle}}
                  </a>
                </li>
              {{/each}}
            </ul>
          {{else}}
            <p>{{i18n "user.summary.no_links"}}</p>
          {{/if}}
        </UserSummarySection>

        <UserSummarySection
          @title="most_replied_to_users"
          class="summary-user-list replied-section pull-right"
        >
          <UserSummaryUsersList
            @none="no_replies"
            @users={{@controller.model.most_replied_to_users}}
            as |user|
          >
            <UserSummaryUser
              @user={{user}}
              @icon="reply"
              @countClass="replies"
            />
          </UserSummaryUsersList>
        </UserSummarySection>
      </div>

      <div class="top-section most-liked-section">
        <UserSummarySection
          @title="most_liked_by"
          class="summary-user-list liked-by-section pull-left"
        >
          <UserSummaryUsersList
            @none="no_likes"
            @users={{@controller.model.most_liked_by_users}}
            as |user|
          >
            <UserSummaryUser @user={{user}} @icon="heart" @countClass="likes" />
          </UserSummaryUsersList>
        </UserSummarySection>

        <UserSummarySection
          @title="most_liked_users"
          class="summary-user-list liked-section pull-right"
        >
          <UserSummaryUsersList
            @none="no_likes"
            @users={{@controller.model.most_liked_users}}
            as |user|
          >
            <UserSummaryUser @user={{user}} @icon="heart" @countClass="likes" />
          </UserSummaryUsersList>
        </UserSummarySection>
      </div>

      {{#if @controller.model.top_categories.length}}
        <div class="top-section top-categories-section">
          <UserSummarySection
            @title="top_categories"
            class="summary-category-list pull-left"
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
                        {{categoryLink
                          category
                          allowUncategorized="true"
                          hideParent=false
                        }}
                      </td>
                      <td class="topic-count">
                        <UserSummaryCategorySearch
                          @user={{@controller.user}}
                          @category={{category}}
                          @searchOnlyFirstPosts={{true}}
                          @count={{category.topic_count}}
                        />
                      </td>
                      <td class="reply-count">
                        <UserSummaryCategorySearch
                          @user={{@controller.user}}
                          @category={{category}}
                          @searchOnlyFirstPosts={{false}}
                          @count={{category.post_count}}
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
                <BadgeCard
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
            <LinkTo
              @route="user.badges"
              @model={{@controller.user}}
              class="more"
            >
              {{i18n "user.summary.more_badges"}}
            </LinkTo>
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
);
