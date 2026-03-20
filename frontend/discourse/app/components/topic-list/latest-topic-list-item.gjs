import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import ItemRepliesCell from "discourse/components/topic-list/item/replies-cell";
import TopicPostBadges from "discourse/components/topic-post-badges";
import TopicStatus from "discourse/components/topic-status";
import lazyHash from "discourse/helpers/lazy-hash";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import { applyValueTransformer } from "discourse/lib/transformer";
import DUserAvatarFlair from "discourse/ui-kit/d-user-avatar-flair";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dTopicLink from "discourse/ui-kit/helpers/d-topic-link";

export default class LatestTopicListItem extends Component {
  get tagClassNames() {
    return this.args.topic.tags?.map((tag) => {
      const tagName = typeof tag === "string" ? tag : tag.name;
      return `tag-${tagName}`;
    });
  }

  get additionalClasses() {
    return applyValueTransformer("latest-topic-list-item-class", [], {
      topic: this.args.topic,
    });
  }

  <template>
    <div
      data-topic-id={{@topic.id}}
      class={{dConcatClass
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
          <DUserLink @user={{@topic.lastPosterUser}}>
            {{dAvatar @topic.lastPosterUser imageSize="large"}}
          </DUserLink>
          <DUserAvatarFlair @user={{@topic.lastPosterUser}} />
        </div>
      </PluginOutlet>

      <div class="main-link">
        <div class="top-row">
          <PluginOutlet
            @name="latest-topic-list-item-main-link-top-row"
            @outletArgs={{lazyHash topic=@topic}}
          >
            <TopicStatus @topic={{@topic}} @context="topic-list" />

            {{dTopicLink @topic}}
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
            {{dCategoryLink @topic.category~}}
            {{~dDiscourseTags @topic mode="list"}}
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
            >{{dFormatDate @topic.bumpedAt format="tiny" noTitle="true"}}</a>
          </div>
        </PluginOutlet>
      </div>
    </div>
  </template>
}
