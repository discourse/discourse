{{body-class "user-summary-page"}}

<div class="user-content" id="user-content">
  <PluginOutlet
    @name="above-user-summary-stats"
    @outletArgs={{hash model=this.model user=this.user}}
  />
  {{#if this.model.can_see_summary_stats}}
    <div class="top-section stats-section">
      <h3 class="stats-title">{{i18n "user.summary.stats"}}</h3>
      <ul>
        <li class="stats-days-visited">
          <UserStat
            @value={{this.model.days_visited}}
            @label="user.summary.days_visited"
          />
        </li>
        <li class="stats-time-read">
          <UserStat
            @value={{this.timeRead}}
            @label="user.summary.time_read"
            @rawTitle={{i18n
              "user.summary.time_read_title"
              duration=this.timeReadMedium
            }}
            @type="string"
          />
        </li>
        {{#if this.showRecentTimeRead}}
          <li class="stats-recent-read">
            <UserStat
              @value={{this.recentTimeRead}}
              @label="user.summary.recent_time_read"
              @rawTitle={{i18n
                "user.summary.recent_time_read_title"
                duration=this.recentTimeReadMedium
              }}
              @type="string"
            />
          </li>
        {{/if}}
        <li class="stats-topics-entered">
          <UserStat
            @value={{this.model.topics_entered}}
            @label="user.summary.topics_entered"
          />
        </li>
        <li class="stats-posts-read">
          <UserStat
            @value={{this.model.posts_read_count}}
            @label="user.summary.posts_read"
          />
        </li>
        {{#if this.model.can_see_user_actions}}
          <li class="stats-likes-given linked-stat">
            <LinkTo @route="userActivity.likesGiven">
              <UserStat
                @value={{this.model.likes_given}}
                @icon="heart"
                @label="user.summary.likes_given"
              />
            </LinkTo>
          </li>
        {{else}}
          <li class="stats-likes-given">
            <UserStat
              @value={{this.model.likes_given}}
              @icon="heart"
              @label="user.summary.likes_given"
            />
          </li>
        {{/if}}
        <li class="stats-likes-received">
          <UserStat
            @value={{this.model.likes_received}}
            @icon="heart"
            @label="user.summary.likes_received"
          />
        </li>
        {{#if this.model.bookmark_count}}
          {{#if this.model.can_see_user_actions}}
            <li class="stats-bookmark-count linked-stat">
              <LinkTo @route="userActivity.bookmarks">
                <UserStat
                  @value={{this.model.bookmark_count}}
                  @label="user.summary.bookmark_count"
                />
              </LinkTo>
            </li>
          {{else}}
            <li class="stats-bookmark-count">
              <UserStat
                @value={{this.model.bookmark_count}}
                @label="user.summary.bookmark_count"
              />
            </li>
          {{/if}}
        {{/if}}
        {{#if this.model.can_see_user_actions}}
          <li class="stats-topic-count linked-stat">
            <LinkTo @route="userActivity.topics">
              <UserStat
                @value={{this.model.topic_count}}
                @label="user.summary.topic_count"
              />
            </LinkTo>
          </li>
        {{else}}
          <li class="stats-topic-count">
            <UserStat
              @value={{this.model.topic_count}}
              @label="user.summary.topic_count"
            />
          </li>
        {{/if}}
        {{#if this.model.can_see_user_actions}}
          <li class="stats-post-count linked-stat">
            <LinkTo @route="userActivity.replies">
              <UserStat
                @value={{this.model.post_count}}
                @label="user.summary.post_count"
              />
            </LinkTo>
          </li>
        {{else}}
          <li class="stats-post-count">
            <UserStat
              @value={{this.model.post_count}}
              @label="user.summary.post_count"
            />
          </li>
        {{/if}}
        <PluginOutlet
          @name="user-summary-stat"
          @connectorTagName="li"
          @outletArgs={{hash model=this.model user=this.user}}
        />
      </ul>
    </div>
  {{/if}}

  <PluginOutlet
    @name="below-user-summary-stats"
    @outletArgs={{hash model=this.model user=this.user}}
  />

  <div class="top-section replies-and-topics-section">
    <UserSummarySection @title="top_replies" class="replies-section pull-left">
      <UserSummaryTopicsList
        @type="replies"
        @items={{this.model.replies}}
        @user={{this.user}}
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

    <UserSummarySection @title="top_topics" class="topics-section pull-right">
      <UserSummaryTopicsList
        @type="topics"
        @items={{this.model.topics}}
        @user={{this.user}}
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
      {{#if this.model.links.length}}
        <ul>
          {{#each this.model.links as |link|}}
            <li>
              {{! template-lint-disable link-rel-noopener }}
              <a
                class="domain"
                href={{link.url}}
                title={{link.title}}
                rel="noopener {{unless
                  this.user.removeNoFollow
                  'nofollow ugc'
                }}"
                target="_blank"
                data-clicks={{link.clicks}}
                aria-label={{i18n "topic_map.clicks" count=link.clicks}}
              >
                {{shorten-url link.url}}
              </a>
              {{! template-lint-enable link-rel-noopener }}
              <br />

              <a href={{link.post_url}}>
                {{html-safe link.topic.fancyTitle}}
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
        @users={{this.model.most_replied_to_users}}
        as |user|
      >
        <UserSummaryUser @user={{user}} @icon="reply" @countClass="replies" />
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
        @users={{this.model.most_liked_by_users}}
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
        @users={{this.model.most_liked_users}}
        as |user|
      >
        <UserSummaryUser @user={{user}} @icon="heart" @countClass="likes" />
      </UserSummaryUsersList>
    </UserSummarySection>
  </div>

  {{#if this.model.top_categories.length}}
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
            {{#each this.model.top_categories as |category|}}
              <tr>
                <PluginOutlet
                  @name="user-summary-top-category-row"
                  @outletArgs={{hash category=category user=this.user}}
                >
                  <td class="category-link">
                    {{category-link
                      category
                      allowUncategorized="true"
                      hideParent=false
                    }}
                  </td>
                  <td class="topic-count">
                    <UserSummaryCategorySearch
                      @user={{this.user}}
                      @category={{category}}
                      @searchOnlyFirstPosts={{true}}
                      @count={{category.topic_count}}
                    />
                  </td>
                  <td class="reply-count">
                    <UserSummaryCategorySearch
                      @user={{this.user}}
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

  {{#if this.siteSettings.enable_badges}}
    <div class="top-section badges-section">
      <h3 class="stats-title">{{i18n "user.summary.top_badges"}}</h3>

      {{#if this.model.badges}}
        <div class="badge-group-list">
          {{#each this.model.badges as |badge|}}
            <BadgeCard
              @badge={{badge}}
              @count={{badge.count}}
              @username={{this.user.username_lower}}
            />
          {{/each}}
          <PluginOutlet
            @name="after-user-summary-badges"
            @outletArgs={{hash model=this.model user=this.user}}
          />
        </div>
      {{else}}
        <p>{{i18n "user.summary.no_badges"}}</p>
      {{/if}}

      {{#if this.moreBadges}}
        <LinkTo @route="user.badges" @model={{this.user}} class="more">
          {{i18n "user.summary.more_badges"}}
        </LinkTo>
      {{/if}}
    </div>
  {{/if}}
</div>