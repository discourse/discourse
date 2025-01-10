<PluginOutlet
  @name="above-latest-topic-list-item"
  @connectorTagName="div"
  @outletArgs={{hash topic=this.topic}}
/>
<div class="topic-poster">
  <UserLink
    @user={{this.topic.lastPosterUser}}
    aria-label={{if
      this.topic.lastPosterUser.username
      (i18n "latest_poster_link" username=this.topic.lastPosterUser.username)
    }}
  >
    {{avatar this.topic.lastPosterUser imageSize="large"}}
  </UserLink>
  <UserAvatarFlair @user={{this.topic.lastPosterUser}} />
</div>
<div class="main-link">
  <div class="top-row">
    {{raw "topic-status" topic=this.topic}}
    {{topic-link this.topic}}
    {{~#if this.topic.featured_link}}
      &nbsp;{{topic-featured-link this.topic}}
    {{/if}}{{! intentionally inline
    to avoid whitespace}}<TopicPostBadges
      @unreadPosts={{this.topic.unread_posts}}
      @unseen={{this.topic.unseen}}
      @url={{this.topic.lastUnreadUrl}}
    />
  </div>
  <div class="bottom-row">
    {{category-link this.topic.category}}{{discourse-tags
      this.topic
      mode="list"
    }}{{! intentionally inline to avoid whitespace}}
    <PluginOutlet
      @name="below-latest-topic-list-item-bottom-row"
      @connectorTagName="span"
      @outletArgs={{hash topic=this.topic}}
    />
  </div>
</div>
<div class="topic-stats">
  <PluginOutlet
    @name="above-latest-topic-list-item-post-count"
    @connectorTagName="div"
    @outletArgs={{hash topic=this.topic}}
  />
  {{raw "list/posts-count-column" topic=this.topic tagName="div"}}
  <div class="topic-last-activity">
    <a
      href={{this.topic.lastPostUrl}}
      title={{this.topic.bumpedAtTitle}}
    >{{format-date this.topic.bumpedAt format="tiny" noTitle="true"}}</a>
  </div>
</div>