import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import ItemRepliesCell from "discourse/components/topic-list/item/replies-cell";
import TopicPostBadges from "discourse/components/topic-post-badges";
import TopicStatus from "discourse/components/topic-status";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import categoryLink from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import discourseTags from "discourse/helpers/discourse-tags";
import formatDate from "discourse/helpers/format-date";
import lazyHash from "discourse/helpers/lazy-hash";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import topicLink from "discourse/helpers/topic-link";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class LatestTopicListItem extends Component {
  get tagClassNames() {
    return this.args.topic.tags?.map((tagName) => `tag-${tagName}`);
  }

  get additionalClasses() {
    return applyValueTransformer("latest-topic-list-item-class", [], {
      topic: this.args.topic,
    });
  }

  <template>
    <div
      data-topic-id={{@topic.id}}
      class={{concatClass
        "latest-topic-list-item"
        this.tagClassNames
        (if @topic.category (concat "category-" @topic.category.fullSlug))
        (if @topic.liked "liked")
        (if @topic.archived "archived")
        (if @topic.bookmarked "bookmarked")
        (if @topic.pinned "pinned")
        (if @topic.closed "closed")
        (if @topic.visited "visited")
        this.additionalClasses
      }}
    >
      <PluginOutlet
        @name="above-latest-topic-list-item"
        @connectorTagName="div"
        @outletArgs={{lazyHash topic=@topic}}
      />

      <PluginOutlet
        @name="latest-topic-list-item-topic-poster"
        @outletArgs={{lazyHash topic=@topic}}
      >
        <div class="topic-poster">
          <UserLink @user={{@topic.lastPosterUser}}>
            {{avatar @topic.lastPosterUser imageSize="large"}}
          </UserLink>
          <UserAvatarFlair @user={{@topic.lastPosterUser}} />
        </div>
      </PluginOutlet>

      <div class="main-link">
        <div class="top-row">
          <PluginOutlet
            @name="latest-topic-list-item-main-link-top-row"
            @outletArgs={{lazyHash topic=@topic}}
          >
            <TopicStatus @topic={{@topic}} @context="topic-list" />

            {{topicLink @topic}}
            {{~#if @topic.featured_link}}
              &nbsp;{{topicFeaturedLink @topic}}
            {{/if~}}
            <TopicPostBadges
              @unreadPosts={{@topic.unread_posts}}
              @unseen={{@topic.unseen}}
              @url={{@topic.lastUnreadUrl}}
            />
          </PluginOutlet>
        </div>

        <div class="bottom-row">
          <PluginOutlet
            @name="latest-topic-list-item-main-link-bottom-row"
            @outletArgs={{lazyHash topic=@topic}}
          >
            {{categoryLink @topic.category~}}
            {{~discourseTags @topic mode="list"}}
          </PluginOutlet>
          <PluginOutlet
            @name="below-latest-topic-list-item-bottom-row"
            @connectorTagName="span"
            @outletArgs={{lazyHash topic=@topic}}
          />
        </div>
      </div>

      <div class="topic-stats">
        <PluginOutlet
          @name="above-latest-topic-list-item-post-count"
          @connectorTagName="div"
          @outletArgs={{lazyHash topic=@topic}}
        />
        <PluginOutlet
          @name="latest-topic-list-item-topic-stats"
          @outletArgs={{lazyHash topic=@topic}}
        >
          <ItemRepliesCell @topic={{@topic}} @tagName="div" />
          <div class="topic-last-activity">
            <a
              href={{@topic.lastPostUrl}}
              title={{@topic.bumpedAtTitle}}
            >{{formatDate @topic.bumpedAt format="tiny" noTitle="true"}}</a>
          </div>
        </PluginOutlet>
      </div>
    </div>
  </template>
}
