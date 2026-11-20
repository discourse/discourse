import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicPostBadges from "discourse/components/topic-post-badges";
import TopicStatus from "discourse/components/topic-status";
import lazyHash from "discourse/helpers/lazy-hash";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";

const FeaturedTopic = <template>
  <div class="featured-topic --glimmer" data-topic-id={{@topic.id}}>
    <TopicStatus @context="topic-list" @topic={{@topic}} />

    <a class="title" href={{@topic.lastUnreadUrl}}>{{trustHTML
        @topic.fancyTitle
      }}</a>

    <PluginOutlet
      @name="topic-list-after-title"
      @outletArgs={{lazyHash topic=@topic}}
    />

    <TopicPostBadges
      @unreadPosts={{@topic.unread_posts}}
      @unseen={{@topic.unseen}}
      @url={{@topic.lastUnreadUrl}}
    />

    <a class="last-posted-at" href={{@topic.lastPostUrl}}>{{dAgeWithTooltip
        @topic.last_posted_at
      }}</a>
  </div>
</template>;

export default FeaturedTopic;
